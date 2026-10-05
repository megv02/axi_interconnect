// axi_top.sv - Top module wrapping two masters, arbiter, and slave
module axi_top #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter ID_WIDTH        = 4,
    parameter STRB_WIDTH      = DATA_WIDTH / 8,
    parameter MEM_DEPTH       = 256,
    parameter REQ_QUEUE_DEPTH = 4,
    parameter OT_QUEUE_DEPTH  = 4,
    parameter QUEUE_DEPTH     = 4
)(
    input  logic ACLK,
    input  logic ARESETn,

    // =========================================================================
    // Master 0 User Interface
    // =========================================================================
    input  logic                    m0_wr_req_valid,
    output logic                    m0_wr_req_ready,
    input  logic [ADDR_WIDTH-1:0]  m0_wr_req_addr,
    input  logic [7:0]             m0_wr_req_len,
    input  logic [1:0]             m0_wr_req_burst,
    input  logic [DATA_WIDTH-1:0]  m0_wr_req_base_data,

    input  logic                    m0_rd_req_valid,
    output logic                    m0_rd_req_ready,
    input  logic [ADDR_WIDTH-1:0]  m0_rd_req_addr,
    input  logic [7:0]             m0_rd_req_len,
    input  logic [1:0]             m0_rd_req_burst,

    output logic                    m0_wr_resp_valid,
    output logic [ID_WIDTH-1:0]    m0_wr_resp_id,
    output logic [1:0]             m0_wr_resp_resp,

    output logic                    m0_rd_data_valid,
    output logic [DATA_WIDTH-1:0]  m0_rd_data_out,
    output logic [ID_WIDTH-1:0]    m0_rd_data_id,
    output logic                    m0_rd_data_last,
    output logic [1:0]             m0_rd_data_resp,

    // =========================================================================
    // Master 1 User Interface
    // =========================================================================
    input  logic                    m1_wr_req_valid,
    output logic                    m1_wr_req_ready,
    input  logic [ADDR_WIDTH-1:0]  m1_wr_req_addr,
    input  logic [7:0]             m1_wr_req_len,
    input  logic [1:0]             m1_wr_req_burst,
    input  logic [DATA_WIDTH-1:0]  m1_wr_req_base_data,

    input  logic                    m1_rd_req_valid,
    output logic                    m1_rd_req_ready,
    input  logic [ADDR_WIDTH-1:0]  m1_rd_req_addr,
    input  logic [7:0]             m1_rd_req_len,
    input  logic [1:0]             m1_rd_req_burst,

    output logic                    m1_wr_resp_valid,
    output logic [ID_WIDTH-1:0]    m1_wr_resp_id,
    output logic [1:0]             m1_wr_resp_resp,

    output logic                    m1_rd_data_valid,
    output logic [DATA_WIDTH-1:0]  m1_rd_data_out,
    output logic [ID_WIDTH-1:0]    m1_rd_data_id,
    output logic                    m1_rd_data_last,
    output logic [1:0]             m1_rd_data_resp
);

    // =========================================================================
    // Internal AXI Wires: Master 0 <-> Arbiter
    // =========================================================================
    logic [ADDR_WIDTH-1:0]  m0_awaddr;
    logic [7:0]             m0_awlen;
    logic [1:0]             m0_awburst;
    logic [ID_WIDTH-1:0]    m0_awid;
    logic                   m0_awvalid;
    logic                   m0_awready;

    logic [DATA_WIDTH-1:0]  m0_wdata;
    logic [STRB_WIDTH-1:0]  m0_wstrb;
    logic                   m0_wlast;
    logic                   m0_wvalid;
    logic                   m0_wready;

    logic [1:0]             m0_bresp;
    logic [ID_WIDTH-1:0]    m0_bid;
    logic                   m0_bvalid;
    logic                   m0_bready;

    logic [ADDR_WIDTH-1:0]  m0_araddr;
    logic [7:0]             m0_arlen;
    logic [1:0]             m0_arburst;
    logic [ID_WIDTH-1:0]    m0_arid;
    logic                   m0_arvalid;
    logic                   m0_arready;

    logic [DATA_WIDTH-1:0]  m0_rdata;
    logic [1:0]             m0_rresp;
    logic                   m0_rlast;
    logic [ID_WIDTH-1:0]    m0_rid;
    logic                   m0_rvalid;
    logic                   m0_rready;

    // =========================================================================
    // Internal AXI Wires: Master 1 <-> Arbiter
    // =========================================================================
    logic [ADDR_WIDTH-1:0]  m1_awaddr;
    logic [7:0]             m1_awlen;
    logic [1:0]             m1_awburst;
    logic [ID_WIDTH-1:0]    m1_awid;
    logic                   m1_awvalid;
    logic                   m1_awready;

    logic [DATA_WIDTH-1:0]  m1_wdata;
    logic [STRB_WIDTH-1:0]  m1_wstrb;
    logic                   m1_wlast;
    logic                   m1_wvalid;
    logic                   m1_wready;

    logic [1:0]             m1_bresp;
    logic [ID_WIDTH-1:0]    m1_bid;
    logic                   m1_bvalid;
    logic                   m1_bready;

    logic [ADDR_WIDTH-1:0]  m1_araddr;
    logic [7:0]             m1_arlen;
    logic [1:0]             m1_arburst;
    logic [ID_WIDTH-1:0]    m1_arid;
    logic                   m1_arvalid;
    logic                   m1_arready;

    logic [DATA_WIDTH-1:0]  m1_rdata;
    logic [1:0]             m1_rresp;
    logic                   m1_rlast;
    logic [ID_WIDTH-1:0]    m1_rid;
    logic                   m1_rvalid;
    logic                   m1_rready;

    // =========================================================================
    // Internal AXI Wires: Arbiter <-> Slave
    // =========================================================================
    logic [ADDR_WIDTH-1:0]  s_awaddr;
    logic [7:0]             s_awlen;
    logic [1:0]             s_awburst;
    logic [ID_WIDTH-1:0]    s_awid;
    logic                   s_awvalid;
    logic                   s_awready;

    logic [DATA_WIDTH-1:0]  s_wdata;
    logic [STRB_WIDTH-1:0]  s_wstrb;
    logic                   s_wlast;
    logic                   s_wvalid;
    logic                   s_wready;

    logic [1:0]             s_bresp;
    logic [ID_WIDTH-1:0]    s_bid;
    logic                   s_bvalid;
    logic                   s_bready;

    logic [ADDR_WIDTH-1:0]  s_araddr;
    logic [7:0]             s_arlen;
    logic [1:0]             s_arburst;
    logic [ID_WIDTH-1:0]    s_arid;
    logic                   s_arvalid;
    logic                   s_arready;

    logic [DATA_WIDTH-1:0]  s_rdata;
    logic [1:0]             s_rresp;
    logic                   s_rlast;
    logic [ID_WIDTH-1:0]    s_rid;
    logic                   s_rvalid;
    logic                   s_rready;

    // =========================================================================
    // Master 0 Instance
    // =========================================================================
    axi4_master #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .ID_WIDTH        (ID_WIDTH),
        .REQ_QUEUE_DEPTH (REQ_QUEUE_DEPTH),
        .OT_QUEUE_DEPTH  (OT_QUEUE_DEPTH)
    ) u_master0 (
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),
        // AW
        .AWADDR         (m0_awaddr),
        .AWLEN          (m0_awlen),
        .AWBURST        (m0_awburst),
        .AWID           (m0_awid),
        .AWVALID        (m0_awvalid),
        .AWREADY        (m0_awready),
        // W
        .WDATA          (m0_wdata),
        .WSTRB          (m0_wstrb),
        .WLAST          (m0_wlast),
        .WVALID         (m0_wvalid),
        .WREADY         (m0_wready),
        // B
        .BRESP          (m0_bresp),
        .BID            (m0_bid),
        .BVALID         (m0_bvalid),
        .BREADY         (m0_bready),
        // AR
        .ARADDR         (m0_araddr),
        .ARLEN          (m0_arlen),
        .ARBURST        (m0_arburst),
        .ARID           (m0_arid),
        .ARVALID        (m0_arvalid),
        .ARREADY        (m0_arready),
        // R
        .RDATA          (m0_rdata),
        .RRESP          (m0_rresp),
        .RLAST          (m0_rlast),
        .RID            (m0_rid),
        .RVALID         (m0_rvalid),
        .RREADY         (m0_rready),
        // User
        .wr_req_valid    (m0_wr_req_valid),
        .wr_req_ready    (m0_wr_req_ready),
        .wr_req_addr     (m0_wr_req_addr),
        .wr_req_len      (m0_wr_req_len),
        .wr_req_burst    (m0_wr_req_burst),
        .wr_req_base_data(m0_wr_req_base_data),
        .rd_req_valid    (m0_rd_req_valid),
        .rd_req_ready    (m0_rd_req_ready),
        .rd_req_addr     (m0_rd_req_addr),
        .rd_req_len      (m0_rd_req_len),
        .rd_req_burst    (m0_rd_req_burst),
        .wr_resp_valid   (m0_wr_resp_valid),
        .wr_resp_id      (m0_wr_resp_id),
        .wr_resp_resp    (m0_wr_resp_resp),
        .rd_data_valid   (m0_rd_data_valid),
        .rd_data_out     (m0_rd_data_out),
        .rd_data_id      (m0_rd_data_id),
        .rd_data_last    (m0_rd_data_last),
        .rd_data_resp    (m0_rd_data_resp)
    );

    // =========================================================================
    // Master 1 Instance
    // =========================================================================
    axi4_master #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .ID_WIDTH        (ID_WIDTH),
        .REQ_QUEUE_DEPTH (REQ_QUEUE_DEPTH),
        .OT_QUEUE_DEPTH  (OT_QUEUE_DEPTH)
    ) u_master1 (
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),
        // AW
        .AWADDR         (m1_awaddr),
        .AWLEN          (m1_awlen),
        .AWBURST        (m1_awburst),
        .AWID           (m1_awid),
        .AWVALID        (m1_awvalid),
        .AWREADY        (m1_awready),
        // W
        .WDATA          (m1_wdata),
        .WSTRB          (m1_wstrb),
        .WLAST          (m1_wlast),
        .WVALID         (m1_wvalid),
        .WREADY         (m1_wready),
        // B
        .BRESP          (m1_bresp),
        .BID            (m1_bid),
        .BVALID         (m1_bvalid),
        .BREADY         (m1_bready),
        // AR
        .ARADDR         (m1_araddr),
        .ARLEN          (m1_arlen),
        .ARBURST        (m1_arburst),
        .ARID           (m1_arid),
        .ARVALID        (m1_arvalid),
        .ARREADY        (m1_arready),
        // R
        .RDATA          (m1_rdata),
        .RRESP          (m1_rresp),
        .RLAST          (m1_rlast),
        .RID            (m1_rid),
        .RVALID         (m1_rvalid),
        .RREADY         (m1_rready),
        // User
        .wr_req_valid    (m1_wr_req_valid),
        .wr_req_ready    (m1_wr_req_ready),
        .wr_req_addr     (m1_wr_req_addr),
        .wr_req_len      (m1_wr_req_len),
        .wr_req_burst    (m1_wr_req_burst),
        .wr_req_base_data(m1_wr_req_base_data),
        .rd_req_valid    (m1_rd_req_valid),
        .rd_req_ready    (m1_rd_req_ready),
        .rd_req_addr     (m1_rd_req_addr),
        .rd_req_len      (m1_rd_req_len),
        .rd_req_burst    (m1_rd_req_burst),
        .wr_resp_valid   (m1_wr_resp_valid),
        .wr_resp_id      (m1_wr_resp_id),
        .wr_resp_resp    (m1_wr_resp_resp),
        .rd_data_valid   (m1_rd_data_valid),
        .rd_data_out     (m1_rd_data_out),
        .rd_data_id      (m1_rd_data_id),
        .rd_data_last    (m1_rd_data_last),
        .rd_data_resp    (m1_rd_data_resp)
    );

    // =========================================================================
    // Arbiter Instance
    // =========================================================================
    axi_arbiter #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .STRB_WIDTH (STRB_WIDTH)
    ) u_arbiter (
        .clk        (ACLK),
        .reset_n    (ARESETn),
        // Master 0
        .m0_awaddr  (m0_awaddr),
        .m0_awlen   (m0_awlen),
        .m0_awburst (m0_awburst),
        .m0_awid    (m0_awid),
        .m0_awvalid (m0_awvalid),
        .m0_awready (m0_awready),
        .m0_wdata   (m0_wdata),
        .m0_wstrb   (m0_wstrb),
        .m0_wvalid  (m0_wvalid),
        .m0_wlast   (m0_wlast),
        .m0_wready  (m0_wready),
        .m0_bresp   (m0_bresp),
        .m0_bid     (m0_bid),
        .m0_bvalid  (m0_bvalid),
        .m0_bready  (m0_bready),
        .m0_araddr  (m0_araddr),
        .m0_arlen   (m0_arlen),
        .m0_arburst (m0_arburst),
        .m0_arid    (m0_arid),
        .m0_arvalid (m0_arvalid),
        .m0_arready (m0_arready),
        .m0_rdata   (m0_rdata),
        .m0_rresp   (m0_rresp),
        .m0_rvalid  (m0_rvalid),
        .m0_rlast   (m0_rlast),
        .m0_rid     (m0_rid),
        .m0_rready  (m0_rready),
        // Master 1
        .m1_awaddr  (m1_awaddr),
        .m1_awlen   (m1_awlen),
        .m1_awburst (m1_awburst),
        .m1_awid    (m1_awid),
        .m1_awvalid (m1_awvalid),
        .m1_awready (m1_awready),
        .m1_wdata   (m1_wdata),
        .m1_wstrb   (m1_wstrb),
        .m1_wvalid  (m1_wvalid),
        .m1_wlast   (m1_wlast),
        .m1_wready  (m1_wready),
        .m1_bresp   (m1_bresp),
        .m1_bid     (m1_bid),
        .m1_bvalid  (m1_bvalid),
        .m1_bready  (m1_bready),
        .m1_araddr  (m1_araddr),
        .m1_arlen   (m1_arlen),
        .m1_arburst (m1_arburst),
        .m1_arid    (m1_arid),
        .m1_arvalid (m1_arvalid),
        .m1_arready (m1_arready),
        .m1_rdata   (m1_rdata),
        .m1_rresp   (m1_rresp),
        .m1_rvalid  (m1_rvalid),
        .m1_rlast   (m1_rlast),
        .m1_rid     (m1_rid),
        .m1_rready  (m1_rready),
        // Slave
        .s_awaddr   (s_awaddr),
        .s_awlen    (s_awlen),
        .s_awburst  (s_awburst),
        .s_awid     (s_awid),
        .s_awvalid  (s_awvalid),
        .s_awready  (s_awready),
        .s_wdata    (s_wdata),
        .s_wstrb    (s_wstrb),
        .s_wvalid   (s_wvalid),
        .s_wlast    (s_wlast),
        .s_wready   (s_wready),
        .s_bresp    (s_bresp),
        .s_bid      (s_bid),
        .s_bvalid   (s_bvalid),
        .s_bready   (s_bready),
        .s_araddr   (s_araddr),
        .s_arlen    (s_arlen),
        .s_arburst  (s_arburst),
        .s_arid     (s_arid),
        .s_arvalid  (s_arvalid),
        .s_arready  (s_arready),
        .s_rdata    (s_rdata),
        .s_rresp    (s_rresp),
        .s_rvalid   (s_rvalid),
        .s_rlast    (s_rlast),
        .s_rid      (s_rid),
        .s_rready   (s_rready)
    );

    // =========================================================================
    // Slave Instance
    // =========================================================================
    axi4_slave #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .ID_WIDTH    (ID_WIDTH),
        .MEM_DEPTH   (MEM_DEPTH),
        .QUEUE_DEPTH (QUEUE_DEPTH)
    ) u_slave (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),
        // AW
        .AWADDR     (s_awaddr),
        .AWLEN      (s_awlen),
        .AWBURST    (s_awburst),
        .AWID       (s_awid),
        .AWVALID    (s_awvalid),
        .AWREADY    (s_awready),
        // W
        .WDATA      (s_wdata),
        .WSTRB      (s_wstrb),
        .WLAST      (s_wlast),
        .WVALID     (s_wvalid),
        .WREADY     (s_wready),
        // B
        .BRESP      (s_bresp),
        .BID        (s_bid),
        .BVALID     (s_bvalid),
        .BREADY     (s_bready),
        // AR
        .ARADDR     (s_araddr),
        .ARLEN      (s_arlen),
        .ARBURST    (s_arburst),
        .ARID       (s_arid),
        .ARVALID    (s_arvalid),
        .ARREADY    (s_arready),
        // R
        .RDATA      (s_rdata),
        .RRESP      (s_rresp),
        .RLAST      (s_rlast),
        .RID        (s_rid),
        .RVALID     (s_rvalid),
        .RREADY     (s_rready)
    );

endmodule