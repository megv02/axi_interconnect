// axi_top_tb.sv - Testbench
`timescale 1ns/1ps

module axi_top_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam CLK_PERIOD = 10;

    // =========================================================================
    // Signals
    // =========================================================================
    logic ACLK;
    logic ARESETn;

    // Master 0 User Interface
    logic                    m0_wr_req_valid;
    logic                    m0_wr_req_ready;
    logic [ADDR_WIDTH-1:0]  m0_wr_req_addr;
    logic [7:0]             m0_wr_req_len;
    logic [1:0]             m0_wr_req_burst;
    logic [DATA_WIDTH-1:0]  m0_wr_req_base_data;

    logic                    m0_rd_req_valid;
    logic                    m0_rd_req_ready;
    logic [ADDR_WIDTH-1:0]  m0_rd_req_addr;
    logic [7:0]             m0_rd_req_len;
    logic [1:0]             m0_rd_req_burst;

    logic                    m0_wr_resp_valid;
    logic [ID_WIDTH-1:0]    m0_wr_resp_id;
    logic [1:0]             m0_wr_resp_resp;

    logic                    m0_rd_data_valid;
    logic [DATA_WIDTH-1:0]  m0_rd_data_out;
    logic [ID_WIDTH-1:0]    m0_rd_data_id;
    logic                    m0_rd_data_last;
    logic [1:0]             m0_rd_data_resp;

    // Master 1 User Interface
    logic                    m1_wr_req_valid;
    logic                    m1_wr_req_ready;
    logic [ADDR_WIDTH-1:0]  m1_wr_req_addr;
    logic [7:0]             m1_wr_req_len;
    logic [1:0]             m1_wr_req_burst;
    logic [DATA_WIDTH-1:0]  m1_wr_req_base_data;

    logic                    m1_rd_req_valid;
    logic                    m1_rd_req_ready;
    logic [ADDR_WIDTH-1:0]  m1_rd_req_addr;
    logic [7:0]             m1_rd_req_len;
    logic [1:0]             m1_rd_req_burst;

    logic                    m1_wr_resp_valid;
    logic [ID_WIDTH-1:0]    m1_wr_resp_id;
    logic [1:0]             m1_wr_resp_resp;

    logic                    m1_rd_data_valid;
    logic [DATA_WIDTH-1:0]  m1_rd_data_out;
    logic [ID_WIDTH-1:0]    m1_rd_data_id;
    logic                    m1_rd_data_last;
    logic [1:0]             m1_rd_data_resp;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    axi_top #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .ID_WIDTH        (ID_WIDTH),
        .MEM_DEPTH       (256),
        .REQ_QUEUE_DEPTH (4),
        .OT_QUEUE_DEPTH  (4),
        .QUEUE_DEPTH     (4)
    ) u_dut (
        .ACLK               (ACLK),
        .ARESETn             (ARESETn),
        // M0
        .m0_wr_req_valid     (m0_wr_req_valid),
        .m0_wr_req_ready     (m0_wr_req_ready),
        .m0_wr_req_addr      (m0_wr_req_addr),
        .m0_wr_req_len       (m0_wr_req_len),
        .m0_wr_req_burst     (m0_wr_req_burst),
        .m0_wr_req_base_data (m0_wr_req_base_data),
        .m0_rd_req_valid     (m0_rd_req_valid),
        .m0_rd_req_ready     (m0_rd_req_ready),
        .m0_rd_req_addr      (m0_rd_req_addr),
        .m0_rd_req_len       (m0_rd_req_len),
        .m0_rd_req_burst     (m0_rd_req_burst),
        .m0_wr_resp_valid    (m0_wr_resp_valid),
        .m0_wr_resp_id       (m0_wr_resp_id),
        .m0_wr_resp_resp     (m0_wr_resp_resp),
        .m0_rd_data_valid    (m0_rd_data_valid),
        .m0_rd_data_out      (m0_rd_data_out),
        .m0_rd_data_id       (m0_rd_data_id),
        .m0_rd_data_last     (m0_rd_data_last),
        .m0_rd_data_resp     (m0_rd_data_resp),
        // M1
        .m1_wr_req_valid     (m1_wr_req_valid),
        .m1_wr_req_ready     (m1_wr_req_ready),
        .m1_wr_req_addr      (m1_wr_req_addr),
        .m1_wr_req_len       (m1_wr_req_len),
        .m1_wr_req_burst     (m1_wr_req_burst),
        .m1_wr_req_base_data (m1_wr_req_base_data),
        .m1_rd_req_valid     (m1_rd_req_valid),
        .m1_rd_req_ready     (m1_rd_req_ready),
        .m1_rd_req_addr      (m1_rd_req_addr),
        .m1_rd_req_len       (m1_rd_req_len),
        .m1_rd_req_burst     (m1_rd_req_burst),
        .m1_wr_resp_valid    (m1_wr_resp_valid),
        .m1_wr_resp_id       (m1_wr_resp_id),
        .m1_wr_resp_resp     (m1_wr_resp_resp),
        .m1_rd_data_valid    (m1_rd_data_valid),
        .m1_rd_data_out      (m1_rd_data_out),
        .m1_rd_data_id       (m1_rd_data_id),
        .m1_rd_data_last     (m1_rd_data_last),
        .m1_rd_data_resp     (m1_rd_data_resp)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial ACLK = 1'b0;
    always #(CLK_PERIOD/2) ACLK = ~ACLK;

        // Capture read data from M0
        // =========================================================================
        // Scoreboard Storage
        // =========================================================================
        logic [DATA_WIDTH-1:0] m0_rd_results [$];
        logic [DATA_WIDTH-1:0] m1_rd_results [$];
        
        // Counter-based capture: track total beats received per master
        int m0_beats_received;
        int m1_beats_received;
        
        initial begin
            m0_beats_received = 0;
            m1_beats_received = 0;
        end
        
        // Capture read data from M0 - use NBA-region-safe sampling
        always @(posedge ACLK) begin
            if (m0_rd_data_valid) begin
                m0_rd_results.push_back(m0_rd_data_out);
                m0_beats_received <= m0_beats_received + 1;
                $display("[%0t] M0 RD DATA: 0x%08h ID=%0d LAST=%0b RESP=%0b",
                         $time, m0_rd_data_out, m0_rd_data_id, m0_rd_data_last, m0_rd_data_resp);
            end
        end
        
        // Capture read data from M1
        always @(posedge ACLK) begin
            if (m1_rd_data_valid) begin
                m1_rd_results.push_back(m1_rd_data_out);
                m1_beats_received <= m1_beats_received + 1;
                $display("[%0t] M1 RD DATA: 0x%08h ID=%0d LAST=%0b RESP=%0b",
                         $time, m1_rd_data_out, m1_rd_data_id, m1_rd_data_last, m1_rd_data_resp);
            end
        end
        
    // =========================================================================
    // Tasks
    // =========================================================================

    // Submit a write request and wait until it's accepted
    task automatic submit_write(
        input  int                    master,  // 0 or 1
        input  logic [ADDR_WIDTH-1:0] addr,
        input  logic [7:0]            len,
        input  logic [1:0]            burst,
        input  logic [DATA_WIDTH-1:0] base_data
    );
        @(posedge ACLK);
        if (master == 0) begin
            m0_wr_req_valid     <= 1'b1;
            m0_wr_req_addr      <= addr;
            m0_wr_req_len       <= len;
            m0_wr_req_burst     <= burst;
            m0_wr_req_base_data <= base_data;
            do @(posedge ACLK); while (!(m0_wr_req_valid && m0_wr_req_ready));
            m0_wr_req_valid <= 1'b0;
        end else begin
            m1_wr_req_valid     <= 1'b1;
            m1_wr_req_addr      <= addr;
            m1_wr_req_len       <= len;
            m1_wr_req_burst     <= burst;
            m1_wr_req_base_data <= base_data;
            do @(posedge ACLK); while (!(m1_wr_req_valid && m1_wr_req_ready));
            m1_wr_req_valid <= 1'b0;
        end
    endtask

    // Submit a read request and wait until it's accepted
    task automatic submit_read(
        input  int                    master,
        input  logic [ADDR_WIDTH-1:0] addr,
        input  logic [7:0]            len,
        input  logic [1:0]            burst
    );
        @(posedge ACLK);
        if (master == 0) begin
            m0_rd_req_valid <= 1'b1;
            m0_rd_req_addr  <= addr;
            m0_rd_req_len   <= len;
            m0_rd_req_burst <= burst;
            do @(posedge ACLK); while (!(m0_rd_req_valid && m0_rd_req_ready));
            m0_rd_req_valid <= 1'b0;
        end else begin
            m1_rd_req_valid <= 1'b1;
            m1_rd_req_addr  <= addr;
            m1_rd_req_len   <= len;
            m1_rd_req_burst <= burst;
            do @(posedge ACLK); while (!(m1_rd_req_valid && m1_rd_req_ready));
            m1_rd_req_valid <= 1'b0;
        end
    endtask

    // Wait for write response from a specific master
    task automatic wait_wr_resp(input int master);
        if (master == 0) begin
            do @(posedge ACLK); while (!m0_wr_resp_valid);
        end else begin
            do @(posedge ACLK); while (!m1_wr_resp_valid);
        end
    endtask

    // Wait for N read beats from a specific master
        // Wait until the cumulative beat counter has advanced by num_beats
        task automatic wait_rd_beats(input int master, input int num_beats);
            int target;
            if (master == 0) begin
                target = m0_beats_received + num_beats;
                while (m0_beats_received < target) @(posedge ACLK);
                // Wait one extra cycle to ensure the NBA update has settled and
                // the queue push has completed
                @(posedge ACLK);
            end else begin
                target = m1_beats_received + num_beats;
                while (m1_beats_received < target) @(posedge ACLK);
                @(posedge ACLK);
            end
        endtask

    // =========================================================================
    // Verification Helpers
    // =========================================================================
    task automatic verify_rd_data(
    input string                  master_name,
    ref   logic [DATA_WIDTH-1:0]  results [$],
    input int                     num_beats,
    input logic [DATA_WIDTH-1:0]  expected_base
);
    logic [DATA_WIDTH-1:0] expected;
    logic [DATA_WIDTH-1:0] actual;
    int available;

    available = results.size();
    $display("[INFO] %s: checking %0d beats, %0d available in queue",
             master_name, num_beats, available);

    if (available < num_beats) begin
        $error("[FAIL] %s: Expected %0d beats, got %0d", master_name, num_beats, available);
        // Drain whatever IS there to avoid corrupting next test
        while (results.size() > 0) void'(results.pop_front());
        return;
    end

    for (int i = 0; i < num_beats; i++) begin
        expected = expected_base + i;
        actual   = results.pop_front();   // Always pop, even on mismatch
        if (actual !== expected) begin
            $error("[FAIL] %s beat %0d: expected 0x%08h, got 0x%08h",
                   master_name, i, expected, actual);
        end else begin
            $display("[PASS] %s beat %0d: 0x%08h", master_name, i, actual);
        end
    end
endtask
    // =========================================================================
    // Test Stimulus
    // =========================================================================
    int test_pass_count;
    int test_fail_count;

    initial begin
        $dumpfile("axi_top_tb.vcd");
        $dumpvars(0, axi_top_tb);

        test_pass_count = 0;
        test_fail_count = 0;

        // Initialize all user inputs
        m0_wr_req_valid     = 1'b0;
        m0_wr_req_addr      = '0;
        m0_wr_req_len       = '0;
        m0_wr_req_burst     = '0;
        m0_wr_req_base_data = '0;
        m0_rd_req_valid     = 1'b0;
        m0_rd_req_addr      = '0;
        m0_rd_req_len       = '0;
        m0_rd_req_burst     = '0;

        m1_wr_req_valid     = 1'b0;
        m1_wr_req_addr      = '0;
        m1_wr_req_len       = '0;
        m1_wr_req_burst     = '0;
        m1_wr_req_base_data = '0;
        m1_rd_req_valid     = 1'b0;
        m1_rd_req_addr      = '0;
        m1_rd_req_len       = '0;
        m1_rd_req_burst     = '0;

        // =====================================================================
        // Reset
        // =====================================================================
        ARESETn = 1'b0;
        repeat (5) @(posedge ACLK);
        ARESETn = 1'b1;
        repeat (3) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 1: M0 Single-beat Write + Read");
        $display("========================================");

        // M0 writes 0xDEAD_BEEF to address 0x00000000
        submit_write(0, 32'h0000_0000, 8'd0, 2'b01, 32'hDEAD_BEEF);
        wait_wr_resp(0);
        $display("[INFO] M0 write response received");

        repeat (5) @(posedge ACLK);

        // M0 reads back from address 0x00000000
        submit_read(0, 32'h0000_0000, 8'd0, 2'b01);
        wait_rd_beats(0, 1);
        verify_rd_data("M0 Test1", m0_rd_results, 1, 32'hDEAD_BEEF);

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 2: M1 Single-beat Write + Read");
        $display("========================================");

        // M1 writes 0xCAFE_0001 to address 0x00000010
        submit_write(1, 32'h0000_0010, 8'd0, 2'b01, 32'hCAFE_0001);
        wait_wr_resp(1);
        $display("[INFO] M1 write response received");

        repeat (5) @(posedge ACLK);

        // M1 reads back from address 0x00000010
        submit_read(1, 32'h0000_0010, 8'd0, 2'b01);
        wait_rd_beats(1, 1);
        verify_rd_data("M1 Test2", m1_rd_results, 1, 32'hCAFE_0001);

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 3: M0 Burst Write (4 beats) + Read");
        $display("========================================");

        // M0 burst write: 4 beats starting at 0x00000020, data = 0x100, 0x101, 0x102, 0x103
        submit_write(0, 32'h0000_0020, 8'd3, 2'b01, 32'h0000_0100);
        wait_wr_resp(0);
        $display("[INFO] M0 burst write response received");

        repeat (5) @(posedge ACLK);

        // M0 burst read: 4 beats from 0x00000020
        submit_read(0, 32'h0000_0020, 8'd3, 2'b01);
        wait_rd_beats(0, 4);
        verify_rd_data("M0 Test3", m0_rd_results, 4, 32'h0000_0100);

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 4: M1 Burst Write (2 beats) + Read");
        $display("========================================");

        // M1 burst write: 2 beats starting at 0x00000040
        submit_write(1, 32'h0000_0040, 8'd1, 2'b01, 32'h0000_0200);
        wait_wr_resp(1);
        $display("[INFO] M1 burst write response received");

        repeat (5) @(posedge ACLK);

        // M1 burst read
        submit_read(1, 32'h0000_0040, 8'd1, 2'b01);
        wait_rd_beats(1, 2);
        verify_rd_data("M1 Test4", m1_rd_results, 2, 32'h0000_0200);

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 5: Simultaneous M0 and M1 Writes");
        $display("========================================");

        // Both masters issue writes concurrently
        fork
            begin
                submit_write(0, 32'h0000_0060, 8'd0, 2'b01, 32'hAAAA_0000);
                wait_wr_resp(0);
                $display("[INFO] M0 concurrent write response received");
            end
            begin
                submit_write(1, 32'h0000_0070, 8'd0, 2'b01, 32'hBBBB_0000);
                wait_wr_resp(1);
                $display("[INFO] M1 concurrent write response received");
            end
        join

        repeat (5) @(posedge ACLK);

        // Verify both writes
        fork
            begin
                submit_read(0, 32'h0000_0060, 8'd0, 2'b01);
                wait_rd_beats(0, 1);
                verify_rd_data("M0 Test5", m0_rd_results, 1, 32'hAAAA_0000);
            end
            begin
                submit_read(1, 32'h0000_0070, 8'd0, 2'b01);
                wait_rd_beats(1, 1);
                verify_rd_data("M1 Test5", m1_rd_results, 1, 32'hBBBB_0000);
            end
        join

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 6: Simultaneous M0 and M1 Burst Writes");
        $display("========================================");

        fork
            begin
                submit_write(0, 32'h0000_0080, 8'd3, 2'b01, 32'h0000_0300);
                wait_wr_resp(0);
                $display("[INFO] M0 concurrent burst write done");
            end
            begin
                submit_write(1, 32'h0000_00A0, 8'd3, 2'b01, 32'h0000_0400);
                wait_wr_resp(1);
                $display("[INFO] M1 concurrent burst write done");
            end
        join

        repeat (5) @(posedge ACLK);

        // Read back both bursts
        fork
            begin
                submit_read(0, 32'h0000_0080, 8'd3, 2'b01);
                wait_rd_beats(0, 4);
                verify_rd_data("M0 Test6", m0_rd_results, 4, 32'h0000_0300);
            end
            begin
                submit_read(1, 32'h0000_00A0, 8'd3, 2'b01);
                wait_rd_beats(1, 4);
                verify_rd_data("M1 Test6", m1_rd_results, 4, 32'h0000_0400);
            end
        join

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 7: M0 Write then M1 Read (Cross-master)");
        $display("========================================");

        // M0 writes to 0xC0
        submit_write(0, 32'h0000_00C0, 8'd0, 2'b01, 32'h1234_5678);
        wait_wr_resp(0);
        $display("[INFO] M0 write to shared address done");

        repeat (5) @(posedge ACLK);

        // M1 reads from 0xC0 (cross-master verification)
        submit_read(1, 32'h0000_00C0, 8'd0, 2'b01);
        wait_rd_beats(1, 1);
        verify_rd_data("M1 Test7 cross-read", m1_rd_results, 1, 32'h1234_5678);

        repeat (5) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 8: Fixed Burst Write + Read (M0)");
        $display("========================================");

        // Fixed burst: all beats go to same address
        // Write 2 beats to same address 0xD0 (last write wins)
        submit_write(0, 32'h0000_00D0, 8'd1, 2'b00, 32'h0000_0500);
        wait_wr_resp(0);
        $display("[INFO] M0 fixed burst write done");

        repeat (5) @(posedge ACLK);

        // Read back - fixed burst reads same address twice
        // Last value written was 0x501 (base_data + 1)
        submit_read(0, 32'h0000_00D0, 8'd0, 2'b00);
        wait_rd_beats(0, 1);
        // The second beat overwrote the first at same address, so we expect 0x501
        verify_rd_data("M0 Test8 fixed", m0_rd_results, 1, 32'h0000_0501);

        repeat (10) @(posedge ACLK);

        $display("\n========================================");
        $display("TEST 9: Sequential Writes from Both Masters");
        $display("========================================");

        // M0 writes first
        submit_write(0, 32'h0000_00E0, 8'd0, 2'b01, 32'hF0F0_F0F0);
        wait_wr_resp(0);

        // Then M1 writes
        submit_write(1, 32'h0000_00F0, 8'd0, 2'b01, 32'h0F0F_0F0F);
        wait_wr_resp(1);

        repeat (5) @(posedge ACLK);

        // Both read back
        submit_read(0, 32'h0000_00E0, 8'd0, 2'b01);
        wait_rd_beats(0, 1);
        verify_rd_data("M0 Test9", m0_rd_results, 1, 32'hF0F0_F0F0);

        submit_read(1, 32'h0000_00F0, 8'd0, 2'b01);
        wait_rd_beats(1, 1);
        verify_rd_data("M1 Test9", m1_rd_results, 1, 32'h0F0F_0F0F);

        repeat (10) @(posedge ACLK);
        
                // =============================================================
        // TEST: M0 INCR Burst Write + Read (4 beats)
        // =============================================================
        $display("\n========================================");
        $display("TEST: M0 INCR Burst Write + Read (4 beats)");
        $display("========================================");

        // INCR burst: 4 beats starting at address 0x200
        // Master writes base_data+0, base_data+1, base_data+2, base_data+3
        // to addresses 0x200, 0x204, 0x208, 0x20C
        submit_write(0, 32'h0000_0200, 8'd3, 2'b01, 32'hA000_0000);
        wait_wr_resp(0);
        $display("[INFO] M0 INCR 4-beat write done");

        repeat (5) @(posedge ACLK);

        // Read back all 4 beats with INCR burst
        submit_read(0, 32'h0000_0200, 8'd3, 2'b01);
        wait_rd_beats(0, 4);
        // Expect: 0xA0000000, 0xA0000001, 0xA0000002, 0xA0000003
        verify_rd_data("M0 INCR 4-beat", m0_rd_results, 4, 32'hA000_0000);

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: M0 INCR Burst Write + Read (8 beats)
        // =============================================================
        $display("\n========================================");
        $display("TEST: M0 INCR Burst Write + Read (8 beats)");
        $display("========================================");

        // INCR burst: 8 beats starting at address 0x300
        // Master writes base_data+0 through base_data+7
        // to addresses 0x300, 0x304, 0x308, ..., 0x31C
        submit_write(0, 32'h0000_0300, 8'd7, 2'b01, 32'hB000_0000);
        wait_wr_resp(0);
        $display("[INFO] M0 INCR 8-beat write done");

        repeat (5) @(posedge ACLK);

        // Read back all 8 beats with INCR burst
        submit_read(0, 32'h0000_0300, 8'd7, 2'b01);
        wait_rd_beats(0, 8);
        // Expect: 0xB0000000 through 0xB0000007
        verify_rd_data("M0 INCR 8-beat", m0_rd_results, 8, 32'hB000_0000);

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: M1 INCR Burst Write + Read (4 beats)
        // =============================================================
        $display("\n========================================");
        $display("TEST: M1 INCR Burst Write + Read (4 beats)");
        $display("========================================");

        // M1 writes 4-beat INCR burst at address 0x400
        submit_write(1, 32'h0000_0400, 8'd3, 2'b01, 32'hC000_0000);
        wait_wr_resp(1);
        $display("[INFO] M1 INCR 4-beat write done");

        repeat (5) @(posedge ACLK);

        submit_read(1, 32'h0000_0400, 8'd3, 2'b01);
        wait_rd_beats(1, 4);
        verify_rd_data("M1 INCR 4-beat", m1_rd_results, 4, 32'hC000_0000);

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: M1 INCR Burst Write + Read (8 beats)
        // =============================================================
        $display("\n========================================");
        $display("TEST: M1 INCR Burst Write + Read (8 beats)");
        $display("========================================");

        // M1 writes 8-beat INCR burst at address 0x500
        submit_write(1, 32'h0000_0500, 8'd7, 2'b01, 32'hD000_0000);
        wait_wr_resp(1);
        $display("[INFO] M1 INCR 8-beat write done");

        repeat (5) @(posedge ACLK);

        submit_read(1, 32'h0000_0500, 8'd7, 2'b01);
        wait_rd_beats(1, 8);
        verify_rd_data("M1 INCR 8-beat", m1_rd_results, 8, 32'hD000_0000);

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: Simultaneous M0 + M1 INCR Burst (4 beats each)
        // =============================================================
        $display("\n========================================");
        $display("TEST: Simultaneous M0+M1 INCR 4-beat Write + Read");
        $display("========================================");

        // Both masters write concurrently to different address ranges
        fork
            begin
                submit_write(0, 32'h0000_0600, 8'd3, 2'b01, 32'hE000_0000);
                wait_wr_resp(0);
                $display("[INFO] M0 concurrent INCR 4-beat write done");
            end
            begin
                submit_write(1, 32'h0000_0700, 8'd3, 2'b01, 32'hF000_0000);
                wait_wr_resp(1);
                $display("[INFO] M1 concurrent INCR 4-beat write done");
            end
        join

        repeat (5) @(posedge ACLK);

        // Both masters read back concurrently
        fork
            begin
                submit_read(0, 32'h0000_0600, 8'd3, 2'b01);
                wait_rd_beats(0, 4);
                verify_rd_data("M0 concurrent INCR 4-beat", m0_rd_results, 4, 32'hE000_0000);
            end
            begin
                submit_read(1, 32'h0000_0700, 8'd3, 2'b01);
                wait_rd_beats(1, 4);
                verify_rd_data("M1 concurrent INCR 4-beat", m1_rd_results, 4, 32'hF000_0000);
            end
        join

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: Simultaneous M0 + M1 INCR Burst (8 beats each)
        // =============================================================
        $display("\n========================================");
        $display("TEST: Simultaneous M0+M1 INCR 8-beat Write + Read");
        $display("========================================");

        fork
            begin
                submit_write(0, 32'h0000_0800, 8'd7, 2'b01, 32'h1100_0000);
                wait_wr_resp(0);
                $display("[INFO] M0 concurrent INCR 8-beat write done");
            end
            begin
                submit_write(1, 32'h0000_0900, 8'd7, 2'b01, 32'h2200_0000);
                wait_wr_resp(1);
                $display("[INFO] M1 concurrent INCR 8-beat write done");
            end
        join

        repeat (5) @(posedge ACLK);

        fork
            begin
                submit_read(0, 32'h0000_0800, 8'd7, 2'b01);
                wait_rd_beats(0, 8);
                verify_rd_data("M0 concurrent INCR 8-beat", m0_rd_results, 8, 32'h1100_0000);
            end
            begin
                submit_read(1, 32'h0000_0900, 8'd7, 2'b01);
                wait_rd_beats(1, 8);
                verify_rd_data("M1 concurrent INCR 8-beat", m1_rd_results, 8, 32'h2200_0000);
            end
        join

        repeat (10) @(posedge ACLK);

        // =============================================================
        // TEST: Cross-master INCR burst verification
        // =============================================================
        $display("\n========================================");
        $display("TEST: M0 writes INCR 4-beat, M1 reads back");
        $display("========================================");

        // M0 writes to 0xA00
        submit_write(0, 32'h0000_0A00, 8'd3, 2'b01, 32'h3300_0000);
        wait_wr_resp(0);
        $display("[INFO] M0 cross-master INCR write done");

        repeat (5) @(posedge ACLK);

        // M1 reads from same address (cross-master verification)
        submit_read(1, 32'h0000_0A00, 8'd3, 2'b01);
        wait_rd_beats(1, 4);
        verify_rd_data("M1 cross-read INCR 4-beat", m1_rd_results, 4, 32'h3300_0000);

        repeat (10) @(posedge ACLK);

        $display("\n========================================");
$display("TEST 10: Back-to-back M0 Writes");
$display("========================================");

submit_write(0, 32'h0000_0100, 8'd0, 2'b01, 32'hAAAA_1111);
wait_wr_resp(0);
submit_write(0, 32'h0000_0104, 8'd0, 2'b01, 32'hBBBB_2222);
wait_wr_resp(0);
submit_write(0, 32'h0000_0108, 8'd0, 2'b01, 32'hCCCC_3333);
wait_wr_resp(0);

repeat (5) @(posedge ACLK);

submit_read(0, 32'h0000_0100, 8'd2, 2'b01);
wait_rd_beats(0, 3);

if (m0_rd_results.size() >= 3) begin
    logic [DATA_WIDTH-1:0] b0, b1, b2;
    b0 = m0_rd_results.pop_front();
    b1 = m0_rd_results.pop_front();
    b2 = m0_rd_results.pop_front();

    if (b0 === 32'hAAAA_1111) $display("[PASS] M0 Test10 beat 0: 0x%08h", b0);
    else $error("[FAIL] M0 Test10 beat 0: expected 0xAAAA1111, got 0x%08h", b0);

    if (b1 === 32'hBBBB_2222) $display("[PASS] M0 Test10 beat 1: 0x%08h", b1);
    else $error("[FAIL] M0 Test10 beat 1: expected 0xBBBB2222, got 0x%08h", b1);

    if (b2 === 32'hCCCC_3333) $display("[PASS] M0 Test10 beat 2: 0x%08h", b2);
    else $error("[FAIL] M0 Test10 beat 2: expected 0xCCCC3333, got 0x%08h", b2);
end else begin
    $error("[FAIL] M0 Test10: only got %0d beats", m0_rd_results.size());
end

repeat (10) @(posedge ACLK);
        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n========================================");
        $display("ALL TESTS COMPLETED");
        $display("========================================\n");

        $finish;
    end
    
        

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #500000;
        $error("[TIMEOUT] Simulation did not complete within 500us");
        $finish;
    end

endmodule
