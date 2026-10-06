// axi4_slave.sv
// AXI4 Slave with FIFO queues, dm_ram memory, burst support,
// and independent write/read execution engines

module axi4_slave #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter STRB_WIDTH      = DATA_WIDTH / 8,
    parameter MEM_DEPTH       = 256,
    parameter QUEUE_DEPTH     = 4
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // AW Channel
    input  logic [ADDR_WIDTH-1:0]   AWADDR,
    input  logic [7:0]              AWLEN,
    input  logic [1:0]              AWBURST,
    input  logic                    AWVALID,
    output logic                    AWREADY,

    // W Channel
    input  logic [DATA_WIDTH-1:0]   WDATA,
    input  logic [STRB_WIDTH-1:0]   WSTRB,
    input  logic                    WLAST,
    input  logic                    WVALID,
    output logic                    WREADY,

    // B Channel
    output logic [1:0]              BRESP,
    output logic                    BVALID,
    input  logic                    BREADY,

    // AR Channel
    input  logic [ADDR_WIDTH-1:0]   ARADDR,
    input  logic [7:0]              ARLEN,
    input  logic [1:0]              ARBURST,
    input  logic                    ARVALID,
    output logic                    ARREADY,

    // R Channel
    output logic [DATA_WIDTH-1:0]   RDATA,
    output logic [1:0]              RRESP,
    output logic                    RLAST,
    output logic                    RVALID,
    input  logic                    RREADY
);

    // =========================================================================
    // Address Conversion
    // =========================================================================
    localparam BYTES_PER_WORD  = DATA_WIDTH / 8;
    localparam WORD_ADDR_BITS  = $clog2(BYTES_PER_WORD);
    localparam MEM_INDEX_BITS  = $clog2(MEM_DEPTH);

    function automatic logic [MEM_INDEX_BITS-1:0] addr_to_index(
        input logic [ADDR_WIDTH-1:0] addr
    );
        return addr[WORD_ADDR_BITS +: MEM_INDEX_BITS];
    endfunction

    // =========================================================================
    // dm_ram Interface Signals
    // =========================================================================
    logic                       ram_we;
    logic [MEM_INDEX_BITS-1:0]  ram_waddr;
    logic [DATA_WIDTH-1:0]      ram_wdata;
    logic [MEM_INDEX_BITS-1:0]  ram_raddr;
    logic [DATA_WIDTH-1:0]      ram_rdata;

    // =========================================================================
    // Instantiate dm_ram
    // =========================================================================
    dm_ram u_dm_ram (
        .clk     (ACLK),
        // Port A: Write
        .we_a    (ram_we),
        .addr_a  (ram_waddr),
        .wdata_a (ram_wdata),
        // Port B: Read
        .addr_b  (ram_raddr),
        .rdata_b (ram_rdata)
    );

    // =========================================================================
    // Queue Entry Type
    // =========================================================================
    typedef struct packed {
        logic [1:0]             burst;
        logic [7:0]             len;
        logic [ADDR_WIDTH-1:0]  addr;
    } queue_entry_t;

    // =========================================================================
    // Write Address Queue
    // =========================================================================
    queue_entry_t wq [0:QUEUE_DEPTH-1];
    logic [$clog2(QUEUE_DEPTH):0] wq_head, wq_tail, wq_count;

    wire wq_full  = (wq_count == QUEUE_DEPTH[$clog2(QUEUE_DEPTH):0]);
    wire wq_empty = (wq_count == 0);

    // =========================================================================
    // Read Address Queue
    // =========================================================================
    queue_entry_t rq [0:QUEUE_DEPTH-1];
    logic [$clog2(QUEUE_DEPTH):0] rq_head, rq_tail, rq_count;

    wire rq_full  = (rq_count == QUEUE_DEPTH[$clog2(QUEUE_DEPTH):0]);
    wire rq_empty = (rq_count == 0);

    // =========================================================================
    // Write Path FSM
    // =========================================================================
    typedef enum logic [2:0] {
        WR_IDLE,
        WR_DATA,
        WR_RMW_READ,   // Read-modify-write: present read address, wait 1 cycle
        WR_RMW_MERGE,  // Read-modify-write: merge and write back
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state;

    logic [ADDR_WIDTH-1:0]  wr_addr;
    logic [8:0]             wr_beats_remaining;
    logic [1:0]             wr_burst;

    // Latched W-channel data for read-modify-write
    logic [DATA_WIDTH-1:0]  wr_wdata_lat;
    logic [STRB_WIDTH-1:0]  wr_wstrb_lat;
    logic                   wr_wlast_lat;

    // =========================================================================
    // Read Path FSM
    // =========================================================================
    typedef enum logic [2:0] {
        RD_IDLE,
        RD_ADDR,    // Present address to RAM, wait for data
        RD_WAIT,    // One-cycle RAM latency
        RD_DATA     // Present data on R channel, wait for RREADY
    } rd_state_t;

    rd_state_t rd_state;

    logic [ADDR_WIDTH-1:0]  rd_addr;
    logic [8:0]             rd_beats_remaining;
    logic [1:0]             rd_burst;

    // =========================================================================
    // Read Port Arbitration
    // =========================================================================
    // Write path needs read port during RMW; read path needs it otherwise.
    // Write RMW gets priority to avoid blocking the write pipeline.
    logic wr_needs_read_port;
    assign wr_needs_read_port = (wr_state == WR_RMW_READ);

    // =========================================================================
    // Enqueue/dequeue flags
    // =========================================================================
    logic wq_enq, wq_deq;
    logic rq_enq, rq_deq;

    // =========================================================================
    // RAM Control (Combinational)
    // =========================================================================
    // Write port defaults
    logic                       ram_we_next;
    logic [MEM_INDEX_BITS-1:0]  ram_waddr_next;
    logic [DATA_WIDTH-1:0]      ram_wdata_next;
    logic [MEM_INDEX_BITS-1:0]  ram_raddr_next;

    always_comb begin
        // Defaults: no write, read address 0
        ram_we_next    = 1'b0;
        ram_waddr_next = '0;
        ram_wdata_next = '0;
        ram_raddr_next = '0;

        // Write port: driven during WR_RMW_MERGE
        if (wr_state == WR_RMW_MERGE) begin
            ram_we_next    = 1'b1;
            ram_waddr_next = addr_to_index(wr_addr);
            // Merge: use latched strobes to select between new data and old (RAM) data
            for (int b = 0; b < STRB_WIDTH; b++) begin
                if (wr_wstrb_lat[b])
                    ram_wdata_next[b*8 +: 8] = wr_wdata_lat[b*8 +: 8];
                else
                    ram_wdata_next[b*8 +: 8] = ram_rdata[b*8 +: 8];
            end
        end

        // Read port arbitration
        if (wr_needs_read_port) begin
            // Write path RMW read
            ram_raddr_next = addr_to_index(wr_addr);
        end else begin
            // Read path
            case (rd_state)
                RD_ADDR:  ram_raddr_next = addr_to_index(rd_addr);
                RD_DATA: begin
                    // Pre-fetch next address if current beat is being accepted
                    if (RVALID && RREADY && !RLAST) begin
                        if (rd_burst == 2'b01)
                            ram_raddr_next = addr_to_index(rd_addr + BYTES_PER_WORD);
                        else
                            ram_raddr_next = addr_to_index(rd_addr);
                    end else begin
                        ram_raddr_next = addr_to_index(rd_addr);
                    end
                end
                default: ram_raddr_next = addr_to_index(rd_addr);
            endcase
        end
    end

    // Drive RAM ports
    assign ram_we    = ram_we_next;
    assign ram_waddr = ram_waddr_next;
    assign ram_wdata = ram_wdata_next;
    assign ram_raddr = ram_raddr_next;

    // =========================================================================
    // Main Sequential Block
    // =========================================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00;

            ARREADY <= 1'b0;
            RVALID  <= 1'b0;
            RDATA   <= '0;
            RRESP   <= 2'b00;
            RLAST   <= 1'b0;

            wq_head  <= '0;
            wq_tail  <= '0;
            wq_count <= '0;

            rq_head  <= '0;
            rq_tail  <= '0;
            rq_count <= '0;

            wr_state           <= WR_IDLE;
            wr_addr            <= '0;
            wr_beats_remaining <= '0;
            wr_burst           <= '0;
            wr_wdata_lat       <= '0;
            wr_wstrb_lat       <= '0;
            wr_wlast_lat       <= 1'b0;

            rd_state           <= RD_IDLE;
            rd_addr            <= '0;
            rd_beats_remaining <= '0;
            rd_burst           <= '0;

        end else begin

            // =============================================================
            // Initialize flags
            // =============================================================
            wq_enq = 1'b0;
            wq_deq = 1'b0;
            rq_enq = 1'b0;
            rq_deq = 1'b0;

            // =============================================================
            // AW CHANNEL: Accept write addresses into queue
            // =============================================================
            AWREADY <= !wq_full;

            if (AWVALID && !wq_full) begin
                wq[wq_tail[$clog2(QUEUE_DEPTH)-1:0]].addr  <= AWADDR;
                wq[wq_tail[$clog2(QUEUE_DEPTH)-1:0]].len   <= AWLEN;
                wq[wq_tail[$clog2(QUEUE_DEPTH)-1:0]].burst <= AWBURST;
                wq_tail <= (wq_tail + 1) % QUEUE_DEPTH;
                wq_enq = 1'b1;
            end

            // =============================================================
            // AR CHANNEL: Accept read addresses into queue
            // =============================================================
            ARREADY <= !rq_full;

            if (ARVALID && !rq_full) begin
                rq[rq_tail[$clog2(QUEUE_DEPTH)-1:0]].addr  <= ARADDR;
                rq[rq_tail[$clog2(QUEUE_DEPTH)-1:0]].len   <= ARLEN;
                rq[rq_tail[$clog2(QUEUE_DEPTH)-1:0]].burst <= ARBURST;
                rq_tail <= (rq_tail + 1) % QUEUE_DEPTH;
                rq_enq = 1'b1;
            end

            // =============================================================
            // WRITE PATH FSM
            // =============================================================
            case (wr_state)
                WR_IDLE: begin
                    WREADY <= 1'b0;
                    BVALID <= 1'b0;

                    if (!wq_empty) begin
                        wr_addr            <= wq[wq_head[$clog2(QUEUE_DEPTH)-1:0]].addr;
                        wr_beats_remaining <= {1'b0, wq[wq_head[$clog2(QUEUE_DEPTH)-1:0]].len} + 9'd1;
                        wr_burst           <= wq[wq_head[$clog2(QUEUE_DEPTH)-1:0]].burst;

                        wq_head <= (wq_head + 1) % QUEUE_DEPTH;
                        wq_deq = 1'b1;

                        WREADY   <= 1'b1;
                        wr_state <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (WVALID && WREADY) begin
                        // Latch incoming W data
                        wr_wdata_lat <= WDATA;
                        wr_wstrb_lat <= WSTRB;
                        wr_wlast_lat <= WLAST;

                        // De-assert WREADY while doing RMW
                        WREADY <= 1'b0;

                        // Check if all strobes are active (skip read phase)
                        if (&WSTRB) begin
                            // Full-word write: skip RMW, go straight to merge
                            // We still go to WR_RMW_MERGE but ram_rdata won't
                            // be used since all strobes are set
                            wr_state <= WR_RMW_READ;
                        end else begin
                            // Partial write: need to read existing data first
                            // Address is presented combinationally via ram_raddr
                            wr_state <= WR_RMW_READ;
                        end
                    end
                end

                WR_RMW_READ: begin
                    // Address was presented to RAM this cycle.
                    // Wait one cycle for ram_rdata to be valid.
                    wr_state <= WR_RMW_MERGE;
                end

                WR_RMW_MERGE: begin
                    // ram_rdata is now valid from previous cycle's address.
                    // The write (ram_we) is driven combinationally in always_comb.
                    // It fires this cycle.

                    wr_beats_remaining <= wr_beats_remaining - 9'd1;

                    // Advance address for next beat
                    if (wr_burst == 2'b01) begin
                        wr_addr <= wr_addr + BYTES_PER_WORD;
                    end
                    // Fixed burst: wr_addr unchanged

                    if (wr_wlast_lat) begin
                        // Generate write response
                        BRESP    <= 2'b00; // OKAY
                        BVALID   <= 1'b1;
                        wr_state <= WR_RESP;
                    end else begin
                        // Accept next beat
                        WREADY   <= 1'b1;
                        wr_state <= WR_DATA;
                    end
                end

                WR_RESP: begin
                    if (BVALID && BREADY) begin
                        BVALID   <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase

            // =============================================================
            // READ PATH FSM
            // =============================================================
            case (rd_state)
                RD_IDLE: begin
                    RVALID <= 1'b0;
                    RLAST  <= 1'b0;

                    if (!rq_empty && !wr_needs_read_port) begin
                        rd_addr            <= rq[rq_head[$clog2(QUEUE_DEPTH)-1:0]].addr;
                        rd_beats_remaining <= {1'b0, rq[rq_head[$clog2(QUEUE_DEPTH)-1:0]].len} + 9'd1;
                        rd_burst           <= rq[rq_head[$clog2(QUEUE_DEPTH)-1:0]].burst;

                        rq_head <= (rq_head + 1) % QUEUE_DEPTH;
                        rq_deq = 1'b1;

                        // Address will be driven combinationally next cycle
                        rd_state <= RD_ADDR;
                    end
                end

                RD_ADDR: begin
                    // Address is presented to RAM combinationally this cycle.
                    // If write path is hogging the read port, stall here.
                    if (!wr_needs_read_port) begin
                        rd_state <= RD_WAIT;
                    end
                    // else: stay in RD_ADDR until read port is free
                end

                RD_WAIT: begin
                    // RAM read data will be available next cycle.
                    // If write stole the port, we need to re-present address.
                    if (wr_needs_read_port) begin
                        rd_state <= RD_ADDR; // retry
                    end else begin
                        // ram_rdata is valid now (address was stable last cycle)
                        RDATA  <= ram_rdata;
                        RRESP  <= 2'b00; // OKAY
                        RLAST  <= (rd_beats_remaining == 9'd1);
                        RVALID <= 1'b1;
                        rd_state <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (RVALID && RREADY) begin
                        rd_beats_remaining <= rd_beats_remaining - 9'd1;

                        if (RLAST) begin
                            // Read transaction complete
                            RVALID   <= 1'b0;
                            RLAST    <= 1'b0;
                            rd_state <= RD_IDLE;
                        end else begin
                            // Advance address for next beat
                            if (rd_burst == 2'b01) begin
                                rd_addr <= rd_addr + BYTES_PER_WORD;
                            end
                            // Fixed burst: rd_addr unchanged

                            // Need to fetch next beat from RAM
                            // Address is driven combinationally (with pre-fetch)
                            RVALID   <= 1'b0;
                            rd_state <= RD_ADDR;
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase

            // =============================================================
            // QUEUE COUNT UPDATES
            // =============================================================
            case ({wq_enq, wq_deq})
                2'b10:   wq_count <= wq_count + 1;
                2'b01:   wq_count <= wq_count - 1;
                default: wq_count <= wq_count;
            endcase

            case ({rq_enq, rq_deq})
                2'b10:   rq_count <= rq_count + 1;
                2'b01:   rq_count <= rq_count - 1;
                default: rq_count <= rq_count;
            endcase

        end
    end

endmodule
