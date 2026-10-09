// axi_arbiter.sv - Fixed: combinational channel muxing
module axi_arbiter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8
)(
    input  logic clk,
    input  logic reset_n,

    // Master 0
    input  logic [ADDR_WIDTH-1:0]  m0_awaddr,
    input  logic [7:0]             m0_awlen,
    input  logic [1:0]             m0_awburst,
    input  logic                   m0_awvalid,
    output logic                   m0_awready,
    input  logic [DATA_WIDTH-1:0]  m0_wdata,
    input  logic [STRB_WIDTH-1:0]  m0_wstrb,
    input  logic                   m0_wvalid,
    input  logic                   m0_wlast,
    output logic                   m0_wready,
    output logic [1:0]             m0_bresp,
    output logic                   m0_bvalid,
    input  logic                   m0_bready,
    input  logic [ADDR_WIDTH-1:0]  m0_araddr,
    input  logic [7:0]             m0_arlen,
    input  logic [1:0]             m0_arburst,
    input  logic                   m0_arvalid,
    output logic                   m0_arready,
    output logic [DATA_WIDTH-1:0]  m0_rdata,
    output logic [1:0]             m0_rresp,
    output logic                   m0_rvalid,
    output logic                   m0_rlast,
    input  logic                   m0_rready,

    // Master 1
    input  logic [ADDR_WIDTH-1:0]  m1_awaddr,
    input  logic [7:0]             m1_awlen,
    input  logic [1:0]             m1_awburst,
    input  logic                   m1_awvalid,
    output logic                   m1_awready,
    input  logic [DATA_WIDTH-1:0]  m1_wdata,
    input  logic [STRB_WIDTH-1:0]  m1_wstrb,
    input  logic                   m1_wvalid,
    input  logic                   m1_wlast,
    output logic                   m1_wready,
    output logic [1:0]             m1_bresp,
    output logic                   m1_bvalid,
    input  logic                   m1_bready,
    input  logic [ADDR_WIDTH-1:0]  m1_araddr,
    input  logic [7:0]             m1_arlen,
    input  logic [1:0]             m1_arburst,
    input  logic                   m1_arvalid,
    output logic                   m1_arready,
    output logic [DATA_WIDTH-1:0]  m1_rdata,
    output logic [1:0]             m1_rresp,
    output logic                   m1_rvalid,
    output logic                   m1_rlast,
    input  logic                   m1_rready,

    // Slave
    output logic [ADDR_WIDTH-1:0]  s_awaddr,
    output logic [7:0]             s_awlen,
    output logic [1:0]             s_awburst,
    output logic                   s_awvalid,
    input  logic                   s_awready,
    output logic [DATA_WIDTH-1:0]  s_wdata,
    output logic [STRB_WIDTH-1:0]  s_wstrb,
    output logic                   s_wvalid,
    output logic                   s_wlast,
    input  logic                   s_wready,
    input  logic [1:0]             s_bresp,
    input  logic                   s_bvalid,
    output logic                   s_bready,
    output logic [ADDR_WIDTH-1:0]  s_araddr,
    output logic [7:0]             s_arlen,
    output logic [1:0]             s_arburst,
    output logic                   s_arvalid,
    input  logic                   s_arready,
    input  logic [DATA_WIDTH-1:0]  s_rdata,
    input  logic [1:0]             s_rresp,
    input  logic                   s_rvalid,
    input  logic                   s_rlast,
    output logic                   s_rready
);

    // =========================================================================
    // Write Arbitration: only the GRANT is registered, all muxing is combinational
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,    // No write in progress, pick a grant
        W_ACTIVE,  // AW + W phases (until WLAST handshake)
        W_RESP     // Waiting for B response
    } warb_state_t;

    warb_state_t warb_state, warb_state_n;
    logic        w_grant, w_grant_n;
    logic        w_last_grant, w_last_grant_n;

    // Combinational mux of all write channels based on w_grant
    always_comb begin
        // Defaults: deassert everything
        m0_awready = 1'b0;
        m1_awready = 1'b0;
        m0_wready  = 1'b0;
        m1_wready  = 1'b0;
        m0_bvalid  = 1'b0;
        m1_bvalid  = 1'b0;
        m0_bresp   = 2'b00;
        m1_bresp   = 2'b00;

        s_awvalid  = 1'b0;
        s_awaddr   = '0;
        s_awlen    = '0;
        s_awburst  = '0;
        s_wvalid   = 1'b0;
        s_wdata    = '0;
        s_wstrb    = '0;
        s_wlast    = 1'b0;
        s_bready   = 1'b0;

        if (warb_state == W_ACTIVE) begin
            // Route AW + W from granted master to slave
            if (!w_grant) begin
                s_awaddr   = m0_awaddr;
                s_awlen    = m0_awlen;
                s_awburst  = m0_awburst;
                s_awvalid  = m0_awvalid;
                m0_awready = s_awready;

                s_wdata    = m0_wdata;
                s_wstrb    = m0_wstrb;
                s_wlast    = m0_wlast;
                s_wvalid   = m0_wvalid;
                m0_wready  = s_wready;
            end else begin
                s_awaddr   = m1_awaddr;
                s_awlen    = m1_awlen;
                s_awburst  = m1_awburst;
                s_awvalid  = m1_awvalid;
                m1_awready = s_awready;

                s_wdata    = m1_wdata;
                s_wstrb    = m1_wstrb;
                s_wlast    = m1_wlast;
                s_wvalid   = m1_wvalid;
                m1_wready  = s_wready;
            end
        end
        else if (warb_state == W_RESP) begin
            // Route B from slave to granted master
            if (!w_grant) begin
                m0_bresp  = s_bresp;
                m0_bvalid = s_bvalid;
                s_bready  = m0_bready;
            end else begin
                m1_bresp  = s_bresp;
                m1_bvalid = s_bvalid;
                s_bready  = m1_bready;
            end
        end
    end

    // Next-state logic for write arbitration
    always_comb begin
        warb_state_n    = warb_state;
        w_grant_n       = w_grant;
        w_last_grant_n  = w_last_grant;

        case (warb_state)
            W_IDLE: begin
                if (m0_awvalid && m1_awvalid) begin
                    w_grant_n = ~w_last_grant;
                    warb_state_n = W_ACTIVE;
                end else if (m0_awvalid) begin
                    w_grant_n = 1'b0;
                    warb_state_n = W_ACTIVE;
                end else if (m1_awvalid) begin
                    w_grant_n = 1'b1;
                    warb_state_n = W_ACTIVE;
                end
            end

            W_ACTIVE: begin
                // Move to W_RESP after the last write beat is accepted by slave
                if (s_wvalid && s_wready && s_wlast) begin
                    warb_state_n = W_RESP;
                end
            end

            W_RESP: begin
                if (s_bvalid && s_bready) begin
                    w_last_grant_n = w_grant;
                    warb_state_n = W_IDLE;
                end
            end

            default: warb_state_n = W_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            warb_state   <= W_IDLE;
            w_grant      <= 1'b0;
            w_last_grant <= 1'b0;
        end else begin
            warb_state   <= warb_state_n;
            w_grant      <= w_grant_n;
            w_last_grant <= w_last_grant_n;
        end
    end

    // =========================================================================
    // Read Arbitration: combinational muxing
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE,
        R_ADDR,    // AR phase
        R_DATA     // R phase
    } rarb_state_t;

    rarb_state_t rarb_state, rarb_state_n;
    logic        r_grant, r_grant_n;
    logic        r_last_grant, r_last_grant_n;

    always_comb begin
        m0_arready = 1'b0;
        m1_arready = 1'b0;
        m0_rvalid  = 1'b0;
        m1_rvalid  = 1'b0;
        m0_rdata   = '0;
        m1_rdata   = '0;
        m0_rresp   = 2'b00;
        m1_rresp   = 2'b00;
        m0_rlast   = 1'b0;
        m1_rlast   = 1'b0;

        s_arvalid  = 1'b0;
        s_araddr   = '0;
        s_arlen    = '0;
        s_arburst  = '0;
        s_rready   = 1'b0;

        if (rarb_state == R_ADDR) begin
            if (!r_grant) begin
                s_araddr   = m0_araddr;
                s_arlen    = m0_arlen;
                s_arburst  = m0_arburst;
                s_arvalid  = m0_arvalid;
                m0_arready = s_arready;
            end else begin
                s_araddr   = m1_araddr;
                s_arlen    = m1_arlen;
                s_arburst  = m1_arburst;
                s_arvalid  = m1_arvalid;
                m1_arready = s_arready;
            end
        end
        else if (rarb_state == R_DATA) begin
            if (!r_grant) begin
                m0_rdata  = s_rdata;
                m0_rresp  = s_rresp;
                m0_rlast  = s_rlast;
                m0_rvalid = s_rvalid;
                s_rready  = m0_rready;
            end else begin
                m1_rdata  = s_rdata;
                m1_rresp  = s_rresp;
                m1_rlast  = s_rlast;
                m1_rvalid = s_rvalid;
                s_rready  = m1_rready;
            end
        end
    end

    always_comb begin
        rarb_state_n   = rarb_state;
        r_grant_n      = r_grant;
        r_last_grant_n = r_last_grant;

        case (rarb_state)
            R_IDLE: begin
                if (m0_arvalid && m1_arvalid) begin
                    r_grant_n = ~r_last_grant;
                    rarb_state_n = R_ADDR;
                end else if (m0_arvalid) begin
                    r_grant_n = 1'b0;
                    rarb_state_n = R_ADDR;
                end else if (m1_arvalid) begin
                    r_grant_n = 1'b1;
                    rarb_state_n = R_ADDR;
                end
            end

            R_ADDR: begin
                if (s_arvalid && s_arready) begin
                    rarb_state_n = R_DATA;
                end
            end

            R_DATA: begin
                if (s_rvalid && s_rready && s_rlast) begin
                    r_last_grant_n = r_grant;
                    rarb_state_n = R_IDLE;
                end
            end

            default: rarb_state_n = R_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rarb_state   <= R_IDLE;
            r_grant      <= 1'b0;
            r_last_grant <= 1'b0;
        end else begin
            rarb_state   <= rarb_state_n;
            r_grant      <= r_grant_n;
            r_last_grant <= r_last_grant_n;
        end
    end

endmodule