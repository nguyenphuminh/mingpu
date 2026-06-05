`timescale 1ns/1ps
import gpu_pkg::*;

// Regression suite
//   Test 1: LOAD; MUL; STORE; HALT  - basic correctness
//   Test 2: LOAD; LOAD; STORE; HALT - consecutive LOADs (deadlock regression)
//   Test 3: LOAD; STORE; HALT       - LOAD immediately before STORE (stale-write regression)
//   Test 4: Restart                 - re-run after done (start clears halted regression)

module gpu_tb;
    logic clk = 0, rst_n, start, done;

    logic [$clog2(NUM_CORES)-1:0] rd_core      = '0;
    logic [ADDR_W-1:0]            rd_addr      = '0;
    logic [DATA_W-1:0]            rd_data;

    logic [$clog2(NUM_CORES)-1:0] init_core      = '0;
    logic [ADDR_W-1:0]            init_addr      = '0;
    logic [DATA_W-1:0]            init_data      = '0;
    logic                         init_we        = 1'b0;
    logic                         init_imem_we   = 1'b0;
    logic [PC_W-1:0]              init_imem_addr = '0;
    logic [INST_W-1:0]            init_imem_data = '0;

    gpu_top dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .done          (done),
        .rd_core       (rd_core),
        .rd_addr       (rd_addr),
        .rd_data       (rd_data),
        .init_core     (init_core),
        .init_addr     (init_addr),
        .init_data     (init_data),
        .init_we       (init_we),
        .init_imem_we  (init_imem_we),
        .init_imem_addr(init_imem_addr),
        .init_imem_data(init_imem_data)
    );

    always #5 clk = ~clk;  // 100 MHz

    int pass_count = 0, fail_count = 0, cycle_count = 0;

    // ----------------------------------------------------------------
    // Tasks
    // ----------------------------------------------------------------

    // Pulse start and wait for done within cycle budget
    task automatic run_and_wait(input int budget, input string test_name);
        @(posedge clk); #1; start = 1'b1;
        @(posedge clk); #1; start = 1'b0;
        cycle_count = 0;
        while (!done && cycle_count < budget) begin
            @(posedge clk);
            cycle_count++;
        end
        if (!done) begin
            $error("[%s] did not complete within %0d cycles - likely a deadlock", test_name, budget);
            $finish;
        end
        $display("--- %s done in ~%0d cycles ---", test_name, cycle_count);
    endtask

    // Read back and verify one core's memory slot
    task automatic check_core(input int core, input int addr,
                               input int expected, input string test_name);
        @(posedge clk); #1;
        rd_core = 4'(core);
        rd_addr = 8'(addr);
        @(posedge clk); #1;
        if (rd_data == 8'(expected)) begin
            $display("PASS  [%s] core %2d mem[%0d] = %3d", test_name, core, addr, rd_data);
            pass_count++;
        end else begin
            $error("FAIL  [%s] core %2d mem[%0d] : expected %3d got %3d",
                   test_name, core, addr, expected, rd_data);
            fail_count++;
        end
    endtask

    // ----------------------------------------------------------------
    // Test body
    // ----------------------------------------------------------------

    initial begin
        $dumpfile("gpu_tb.vcd");
        $dumpvars(0, gpu_tb);

        // Reset
        rst_n = 0; start = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        // ----------------------------------------------------------------
        // Test 1: LOAD; MUL; STORE; HALT
        // mem[0] = i, acc = mem[0]*3, mem[1] = acc
        // expected: mem[1] = i*3
        // ----------------------------------------------------------------
        @(posedge clk); #1; init_imem_addr = 0; init_imem_data = {8'd4, 8'd0}; init_imem_we = 1'b1; // LOAD 0
        @(posedge clk); #1; init_imem_addr = 1; init_imem_data = {8'd2, 8'd3}; init_imem_we = 1'b1; // MUL  3
        @(posedge clk); #1; init_imem_addr = 2; init_imem_data = {8'd3, 8'd1}; init_imem_we = 1'b1; // STORE 1
        @(posedge clk); #1; init_imem_addr = 3; init_imem_data = {8'd5, 8'd0}; init_imem_we = 1'b1; // HALT
        @(posedge clk); #1; init_imem_we = 1'b0;

        for (int i = 0; i < NUM_CORES; i++) begin
            @(posedge clk); #1;
            init_core = 4'(i); init_addr = 8'd0; init_data = 8'(i); init_we = 1'b1;
        end
        @(posedge clk); #1; init_we = 1'b0;

        run_and_wait(50, "Test1");
        for (int i = 0; i < NUM_CORES; i++)
            check_core(i, 1, i*3, "Test1");

        // ----------------------------------------------------------------
        // Test 2: LOAD; LOAD; STORE; HALT  (deadlock regression)
        // Two consecutive LOADs - would hang forever on old RTL.
        // mem[0]=i (from Test 1), mem[2]=i*2
        // Second LOAD overwrites acc, so mem[3] = mem[2] = i*2
        // expected: mem[3] = i*2
        // ----------------------------------------------------------------
        @(posedge clk); #1; init_imem_addr = 0; init_imem_data = {8'd4, 8'd0}; init_imem_we = 1'b1; // LOAD 0
        @(posedge clk); #1; init_imem_addr = 1; init_imem_data = {8'd4, 8'd2}; init_imem_we = 1'b1; // LOAD 2
        @(posedge clk); #1; init_imem_addr = 2; init_imem_data = {8'd3, 8'd3}; init_imem_we = 1'b1; // STORE 3
        @(posedge clk); #1; init_imem_addr = 3; init_imem_data = {8'd5, 8'd0}; init_imem_we = 1'b1; // HALT
        @(posedge clk); #1; init_imem_we = 1'b0;

        for (int i = 0; i < NUM_CORES; i++) begin
            @(posedge clk); #1;
            init_core = 4'(i); init_addr = 8'd2; init_data = 8'(i*2); init_we = 1'b1;
        end
        @(posedge clk); #1; init_we = 1'b0;

        run_and_wait(50, "Test2");
        for (int i = 0; i < NUM_CORES; i++)
            check_core(i, 3, i*2, "Test2");

        // ----------------------------------------------------------------
        // Test 3: LOAD; STORE; HALT  (stale-write regression)
        // STORE immediately after LOAD - old RTL would write stale acc=0.
        // mem[0] = i+1 so a stale write of 0 is distinguishable.
        // expected: mem[1] = i+1
        // ----------------------------------------------------------------
        @(posedge clk); #1; init_imem_addr = 0; init_imem_data = {8'd4, 8'd0}; init_imem_we = 1'b1; // LOAD 0
        @(posedge clk); #1; init_imem_addr = 1; init_imem_data = {8'd3, 8'd1}; init_imem_we = 1'b1; // STORE 1
        @(posedge clk); #1; init_imem_addr = 2; init_imem_data = {8'd5, 8'd0}; init_imem_we = 1'b1; // HALT
        @(posedge clk); #1; init_imem_we = 1'b0;

        for (int i = 0; i < NUM_CORES; i++) begin
            @(posedge clk); #1;
            init_core = 4'(i); init_addr = 8'd0; init_data = 8'(i+1); init_we = 1'b1;
        end
        @(posedge clk); #1; init_we = 1'b0;

        run_and_wait(50, "Test3");
        for (int i = 0; i < NUM_CORES; i++)
            check_core(i, 1, i+1, "Test3");

        // ----------------------------------------------------------------
        // Test 4: Restart
        // Re-run after done to verify start correctly clears halted.
        // Same program as Test 1, mem[0] = i+5.
        // expected: mem[1] = (i+5)*3
        // ----------------------------------------------------------------
        @(posedge clk); #1; init_imem_addr = 0; init_imem_data = {8'd4, 8'd0}; init_imem_we = 1'b1; // LOAD 0
        @(posedge clk); #1; init_imem_addr = 1; init_imem_data = {8'd2, 8'd3}; init_imem_we = 1'b1; // MUL  3
        @(posedge clk); #1; init_imem_addr = 2; init_imem_data = {8'd3, 8'd1}; init_imem_we = 1'b1; // STORE 1
        @(posedge clk); #1; init_imem_addr = 3; init_imem_data = {8'd5, 8'd0}; init_imem_we = 1'b1; // HALT
        @(posedge clk); #1; init_imem_we = 1'b0;

        for (int i = 0; i < NUM_CORES; i++) begin
            @(posedge clk); #1;
            init_core = 4'(i); init_addr = 8'd0; init_data = 8'(i+5); init_we = 1'b1;
        end
        @(posedge clk); #1; init_we = 1'b0;

        run_and_wait(50, "Test4");
        for (int i = 0; i < NUM_CORES; i++)
            check_core(i, 1, (i+5)*3, "Test4");

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("=== %0d / %0d passed ===", pass_count, pass_count + fail_count);
        if (fail_count) $error("%0d test(s) failed", fail_count);
        $finish;
    end

    // Global timeout watchdog
    initial begin
        #500_000;
        $error("Global TIMEOUT");
        $finish;
    end
endmodule
