// axi4_master.sv
// AXI4 Master with independent channel FSMs, request queues,
// and outstanding transaction queues

module axi4_master #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter STRB_WIDTH       = DATA_WIDTH / 8,
    parameter REQ_QUEUE_DEPTH  = 4,
    parameter OT_QUEUE_DEPTH   = 4
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // AW Channel
    output logic [ADDR_WIDTH-1:0]   AWADDR,
    output logic [7:0]              AWLEN,
    output logic [1:0]              AWBURST,
    output logic                    AWVALID,
    input  logic                    AWREADY,

    // W Channel
    output logic [DATA_WIDTH-1:0]   WDATA,
    output logic [STRB_WIDTH-1:0]   WSTRB,
    output logic                    WLAST,
    output logic                    WVALID,
    input  logic                    WREADY,

    // B Channel
    input  logic [1:0]              BRESP,
    input  logic                    BVALID,
    output logic                    BREADY,

    // AR Channel
    output logic [ADDR_WIDTH-1:0]   ARADDR,
    output logic [7:0]              ARLEN,
    output logic [1:0]              ARBURST,
    output logic                    ARVALID,
    input  logic                    ARREADY,

    // R Channel
    input  logic [DATA_WIDTH-1:0]   RDATA,
    input  logic [1:0]              RRESP,
    input  logic                    RLAST,
    input  logic                    RVALID,
    output logic                    RREADY,

    // User Write Request Interface
    input  logic                    wr_req_valid,
    output logic                    wr_req_ready,
    input  logic [ADDR_WIDTH-1:0]   wr_req_addr,
    input  logic [7:0]              wr_req_len,
    input  logic [1:0]              wr_req_burst,
    input  logic [DATA_WIDTH-1:0]   wr_req_base_data,

    // User Read Request Interface
    input  logic                    rd_req_valid,
    output logic                    rd_req_ready,
    input  logic [ADDR_WIDTH-1:0]   rd_req_addr,
    input  logic [7:0]              rd_req_len,
    input  logic [1:0]              rd_req_burst,

    // Write Response Output
    output logic                    wr_resp_valid,
    output logic [1:0]              wr_resp_resp,

    // Read Data Output
    output logic                    rd_data_valid,
    output logic [DATA_WIDTH-1:0]   rd_data_out,
    output logic                    rd_data_last,
    output logic [1:0]              rd_data_resp
);

    // =========================================================================
    // Queue Entry Types
    // =========================================================================
    typedef struct packed {
        logic [DATA_WIDTH-1:0]  base_data;
        logic [1:0]             burst;
        logic [7:0]             len;
        logic [ADDR_WIDTH-1:0]  addr;
    } write_request_t;

    typedef struct packed {
        logic [1:0]             burst;
        logic [7:0]             len;
        logic [ADDR_WIDTH-1:0]  addr;
    } read_request_t;

    // =========================================================================
    // Write Request Queue
    // =========================================================================
    write_request_t wr_req_queue [0:REQ_QUEUE_DEPTH-1];
    logic [$clog2(REQ_QUEUE_DEPTH):0] wr_req_head, wr_req_tail, wr_req_count;

    wire wr_req_full  = (wr_req_count == REQ_QUEUE_DEPTH[$clog2(REQ_QUEUE_DEPTH):0]);
    wire wr_req_empty = (wr_req_count == 0);
    assign wr_req_ready = !wr_req_full;

    // =========================================================================
    // Read Request Queue
    // =========================================================================
    read_request_t rd_req_queue [0:REQ_QUEUE_DEPTH-1];
    logic [$clog2(REQ_QUEUE_DEPTH):0] rd_req_head, rd_req_tail, rd_req_count;

    wire rd_req_full  = (rd_req_count == REQ_QUEUE_DEPTH[$clog2(REQ_QUEUE_DEPTH):0]);
    wire rd_req_empty = (rd_req_count == 0);
    assign rd_req_ready = !rd_req_full;

    // =========================================================================
    // Outstanding Write Queue (AW FSM -> W FSM)
    // =========================================================================
    write_request_t ot_wr_queue [0:OT_QUEUE_DEPTH-1];
    logic [$clog2(OT_QUEUE_DEPTH):0] ot_wr_head, ot_wr_tail, ot_wr_count;

    wire ot_wr_full  = (ot_wr_count == OT_QUEUE_DEPTH[$clog2(OT_QUEUE_DEPTH):0]);
    wire ot_wr_empty = (ot_wr_count == 0);

    // =========================================================================
    // Outstanding Read Queue (AR FSM -> R FSM)
    // =========================================================================
    read_request_t ot_rd_queue [0:OT_QUEUE_DEPTH-1];
    logic [$clog2(OT_QUEUE_DEPTH):0] ot_rd_head, ot_rd_tail, ot_rd_count;

    wire ot_rd_full  = (ot_rd_count == OT_QUEUE_DEPTH[$clog2(OT_QUEUE_DEPTH):0]);
    wire ot_rd_empty = (ot_rd_count == 0);

    // =========================================================================
    // ID Counters
    // =========================================================================

    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [1:0] { AW_IDLE, AW_VALID } aw_state_t;
    typedef enum logic [1:0] { W_IDLE, W_ACTIVE, W_WAIT_RESP } w_state_t;
    typedef enum logic [1:0] { AR_IDLE, AR_VALID } ar_state_t;
    typedef enum logic [1:0] { R_IDLE, R_ACTIVE } r_state_t;

    aw_state_t aw_state;
    w_state_t  w_state;
    ar_state_t ar_state;
    r_state_t  r_state;

    // =========================================================================
    // W FSM Working Registers
    // =========================================================================
    logic [ADDR_WIDTH-1:0]  w_addr;
    logic [8:0]             w_beats_total;
    logic [8:0]             w_beat_count;   // counts 0, 1, 2, ...
    logic [1:0]             w_burst;
    logic [DATA_WIDTH-1:0]  w_base_data;

    // =========================================================================
    // Latched AW request for handshake
    // =========================================================================
    write_request_t aw_pending;

    // =========================================================================
    // Latched AR request for handshake
    // =========================================================================
    read_request_t ar_pending;

    // =========================================================================
    // Enqueue/dequeue control signals to avoid double-update of counts
    // =========================================================================
    logic wr_req_enq, wr_req_deq;
    logic rd_req_enq, rd_req_deq;
    logic ot_wr_enq,  ot_wr_deq;
    logic ot_rd_enq,  ot_rd_deq;
    
     // Add active read tracking registers
                logic [ADDR_WIDTH-1:0]  r_active_addr;
                logic [7:0]             r_active_len;
                logic [1:0]             r_active_burst;
                logic [8:0]             r_beats_remaining;

    // =========================================================================
    // Main Sequential Block
    // =========================================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_state    <= AW_IDLE;
            w_state     <= W_IDLE;
            ar_state    <= AR_IDLE;
            r_state     <= R_IDLE;

            AWVALID     <= 1'b0;
            AWADDR      <= '0;
            AWLEN       <= '0;
            AWBURST     <= '0;

            WVALID      <= 1'b0;
            WDATA       <= '0;
            WSTRB       <= '0;
            WLAST       <= 1'b0;

            BREADY      <= 1'b0;

            ARVALID     <= 1'b0;
            ARADDR      <= '0;
            ARLEN       <= '0;
            ARBURST     <= '0;

            RREADY      <= 1'b0;

            wr_resp_valid <= 1'b0;
            wr_resp_resp  <= '0;

            rd_data_valid <= 1'b0;
            rd_data_out   <= '0;
            rd_data_last  <= 1'b0;
            rd_data_resp  <= '0;


            wr_req_head  <= '0;
            wr_req_tail  <= '0;
            wr_req_count <= '0;

            rd_req_head  <= '0;
            rd_req_tail  <= '0;
            rd_req_count <= '0;

            ot_wr_head   <= '0;
            ot_wr_tail   <= '0;
            ot_wr_count  <= '0;

            ot_rd_head   <= '0;
            ot_rd_tail   <= '0;
            ot_rd_count  <= '0;

            w_addr       <= '0;
            w_beats_total<= '0;
            w_beat_count <= '0;
            w_burst      <= '0;
            w_base_data  <= '0;

        end else begin

            // =============================================================
            // Clear single-cycle pulse outputs
            // =============================================================
            wr_resp_valid <= 1'b0;
            rd_data_valid <= 1'b0;

            // =============================================================
            // Initialize enqueue/dequeue flags
            // =============================================================
            wr_req_enq = 1'b0;
            wr_req_deq = 1'b0;
            rd_req_enq = 1'b0;
            rd_req_deq = 1'b0;
            ot_wr_enq  = 1'b0;
            ot_wr_deq  = 1'b0;
            ot_rd_enq  = 1'b0;
            ot_rd_deq  = 1'b0;

            // =============================================================
            // USER WRITE REQUEST ENQUEUE
            // =============================================================
            if (wr_req_valid && !wr_req_full) begin
                wr_req_queue[wr_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].addr      <= wr_req_addr;
                wr_req_queue[wr_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].len       <= wr_req_len;
                wr_req_queue[wr_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].burst     <= wr_req_burst;
                wr_req_queue[wr_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].base_data <= wr_req_base_data;
                wr_req_tail   <= (wr_req_tail + 1) % REQ_QUEUE_DEPTH;
                wr_req_enq = 1'b1;
            end

            // =============================================================
            // USER READ REQUEST ENQUEUE
            // =============================================================
            if (rd_req_valid && !rd_req_full) begin
                rd_req_queue[rd_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].addr  <= rd_req_addr;
                rd_req_queue[rd_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].len   <= rd_req_len;
                rd_req_queue[rd_req_tail[$clog2(REQ_QUEUE_DEPTH)-1:0]].burst <= rd_req_burst;
                rd_req_tail  <= (rd_req_tail + 1) % REQ_QUEUE_DEPTH;
                rd_req_enq = 1'b1;
            end

            // =============================================================
            // AW CHANNEL FSM
            // =============================================================
            case (aw_state)
                AW_IDLE: begin
                    AWVALID <= 1'b0;
                    if (!wr_req_empty && !ot_wr_full) begin
                        // Latch the request data before dequeuing
                        aw_pending <= wr_req_queue[wr_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]];

                        AWADDR  <= wr_req_queue[wr_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].addr;
                        AWLEN   <= wr_req_queue[wr_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].len;
                        AWBURST <= wr_req_queue[wr_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].burst;
                        AWVALID <= 1'b1;

                        // Dequeue from write request queue
                        wr_req_head <= (wr_req_head + 1) % REQ_QUEUE_DEPTH;
                        wr_req_deq = 1'b1;

                        aw_state <= AW_VALID;
                    end
                end

                AW_VALID: begin
                    if (AWVALID && AWREADY) begin
                        // AW handshake done - push to outstanding queue
                        ot_wr_queue[ot_wr_tail[$clog2(OT_QUEUE_DEPTH)-1:0]] <= aw_pending;
                        ot_wr_tail <= (ot_wr_tail + 1) % OT_QUEUE_DEPTH;
                        ot_wr_enq = 1'b1;

                        AWVALID  <= 1'b0;
                        aw_state <= AW_IDLE;
                    end
                end

                default: aw_state <= AW_IDLE;
            endcase

            // =============================================================
            // W CHANNEL FSM
            // =============================================================
            case (w_state)
                W_IDLE: begin
                    WVALID <= 1'b0;
                    WLAST  <= 1'b0;
                    BREADY <= 1'b0;

                    if (!ot_wr_empty) begin
                        // Load transaction from outstanding queue
                        w_addr       <= ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].addr;
                        w_beats_total<= {1'b0, ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].len} + 9'd1;
                        w_burst      <= ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].burst;
                        w_base_data  <= ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].base_data;
                        w_beat_count <= 9'd0;

                        // First beat on W channel
                        WDATA  <= ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].base_data;
                        WSTRB  <= {STRB_WIDTH{1'b1}};
                        // Single beat?
                        WLAST  <= (ot_wr_queue[ot_wr_head[$clog2(OT_QUEUE_DEPTH)-1:0]].len == 8'd0);
                        WVALID <= 1'b1;

                        // Dequeue from outstanding write queue
                        ot_wr_head <= (ot_wr_head + 1) % OT_QUEUE_DEPTH;
                        ot_wr_deq = 1'b1;

                        w_state <= W_ACTIVE;
                    end
                end

                W_ACTIVE: begin
                    if (WVALID && WREADY) begin
                        w_beat_count <= w_beat_count + 9'd1;

                        if (WLAST) begin
                            // All beats sent
                            WVALID  <= 1'b0;
                            WLAST   <= 1'b0;
                            BREADY  <= 1'b1;
                            w_state <= W_WAIT_RESP;
                        end else begin
                            // Prepare next beat
                            w_base_data <= w_base_data + 1;
                            WDATA       <= w_base_data + 1;

                            if (w_burst == 2'b01) begin
                                w_addr <= w_addr + (DATA_WIDTH / 8);
                            end

                            // Is the NEXT beat the last?
                            if (w_beat_count + 9'd2 == w_beats_total) begin
                                WLAST <= 1'b1;
                            end
                        end
                    end
                end

                W_WAIT_RESP: begin
                    if (BVALID && BREADY) begin
                        wr_resp_valid <= 1'b1;
                        wr_resp_resp  <= BRESP;
                        BREADY        <= 1'b0;
                        w_state       <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase

            // =============================================================
            // AR CHANNEL FSM
            // =============================================================
            case (ar_state)
                AR_IDLE: begin
                    ARVALID <= 1'b0;
                    if (!rd_req_empty && !ot_rd_full) begin
                        ar_pending <= rd_req_queue[rd_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]];

                        ARADDR  <= rd_req_queue[rd_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].addr;
                        ARLEN   <= rd_req_queue[rd_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].len;
                        ARBURST <= rd_req_queue[rd_req_head[$clog2(REQ_QUEUE_DEPTH)-1:0]].burst;
                        ARVALID <= 1'b1;

                        rd_req_head <= (rd_req_head + 1) % REQ_QUEUE_DEPTH;
                        rd_req_deq = 1'b1;

                        ar_state <= AR_VALID;
                    end
                end

                AR_VALID: begin
                    if (ARVALID && ARREADY) begin
                        ot_rd_queue[ot_rd_tail[$clog2(OT_QUEUE_DEPTH)-1:0]] <= ar_pending;
                        ot_rd_tail <= (ot_rd_tail + 1) % OT_QUEUE_DEPTH;
                        ot_rd_enq = 1'b1;

                        ARVALID  <= 1'b0;
                        ar_state <= AR_IDLE;
                    end
                end

                default: ar_state <= AR_IDLE;
            endcase
                
                // R CHANNEL FSM
                case (r_state)
                    R_IDLE: begin
                        RREADY <= 1'b0;
                        if (!ot_rd_empty) begin
                            // Latch the head entry - do NOT dequeue yet
                            r_active_addr      <= ot_rd_queue[ot_rd_head[$clog2(OT_QUEUE_DEPTH)-1:0]].addr;
                            r_active_len       <= ot_rd_queue[ot_rd_head[$clog2(OT_QUEUE_DEPTH)-1:0]].len;
                            r_active_burst     <= ot_rd_queue[ot_rd_head[$clog2(OT_QUEUE_DEPTH)-1:0]].burst;
                            r_beats_remaining  <= {1'b0, ot_rd_queue[ot_rd_head[$clog2(OT_QUEUE_DEPTH)-1:0]].len} + 9'd1;
                            RREADY  <= 1'b1;
                            r_state <= R_ACTIVE;
                            // NOTE: do NOT dequeue here
                        end
                    end
                
                    R_ACTIVE: begin
                        if (RVALID && RREADY) begin
                            rd_data_valid <= 1'b1;
                            rd_data_out   <= RDATA;
                            rd_data_last  <= RLAST;
                            rd_data_resp  <= RRESP;
                
                            r_beats_remaining <= r_beats_remaining - 9'd1;
                
                            if (RLAST) begin
                                // NOW dequeue - transaction is fully complete
                                ot_rd_head <= (ot_rd_head + 1) % OT_QUEUE_DEPTH;
                                ot_rd_deq  = 1'b1;
                
                                RREADY  <= 1'b0;
                                r_state <= R_IDLE;
                            end
                        end
                    end
                
                    default: r_state <= R_IDLE;
                endcase 

            // =============================================================
            // QUEUE COUNT UPDATES (handle simultaneous enq/deq correctly)
            // =============================================================
            case ({wr_req_enq, wr_req_deq})
                2'b10:   wr_req_count <= wr_req_count + 1;
                2'b01:   wr_req_count <= wr_req_count - 1;
                default: wr_req_count <= wr_req_count; // 2'b00 or 2'b11
            endcase

            case ({rd_req_enq, rd_req_deq})
                2'b10:   rd_req_count <= rd_req_count + 1;
                2'b01:   rd_req_count <= rd_req_count - 1;
                default: rd_req_count <= rd_req_count;
            endcase

            case ({ot_wr_enq, ot_wr_deq})
                2'b10:   ot_wr_count <= ot_wr_count + 1;
                2'b01:   ot_wr_count <= ot_wr_count - 1;
                default: ot_wr_count <= ot_wr_count;
            endcase

            case ({ot_rd_enq, ot_rd_deq})
                2'b10:   ot_rd_count <= ot_rd_count + 1;
                2'b01:   ot_rd_count <= ot_rd_count - 1;
                default: ot_rd_count <= ot_rd_count;
            endcase

        end
    end

endmodule
