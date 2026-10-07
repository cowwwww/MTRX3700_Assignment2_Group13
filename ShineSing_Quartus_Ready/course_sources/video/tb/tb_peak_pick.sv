`timescale 1ns/1ps
// tb_peak_pick: a 64-entry profile with peaks at 10, 12 (two sides of a gap), 30, 31 (plateau), 50, and noise below thr.
module tb_peak_pick;
    localparam int W = 64;
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1, start = 0, busy, done; logic [19:0] thr; logic [5:0] min_gap, rd_x; logic [19:0] rd_val;
    logic [5:0] count; logic [4:0] idx; logic [5:0] pos_of;
    logic [19:0] prof [0:W-1];
    always_ff @(posedge clk) rd_val <= prof[rd_x];          // the one-cycle read latency of col_profile
    peak_pick #(.W(W), .AW(20), .NMAX(32)) dut (.*);
    int errors = 0;
    task automatic run(input int gap, input int exp_n, input int exp_pos[]);
        min_gap = gap; @(negedge clk); start = 1; @(negedge clk); start = 0;
        wait (done); @(negedge clk);
        if (count != exp_n) begin errors++; $display("FAIL: min_gap %0d: %0d peaks, expected %0d", gap, count, exp_n); end
        for (int i = 0; i < exp_n && i < count; i++) begin
            idx = i; #1;
            if (pos_of != exp_pos[i]) begin errors++; $display("FAIL: min_gap %0d: peak %0d at %0d, expected %0d", gap, i, pos_of, exp_pos[i]); end
        end
    endtask
    initial begin
        `ifdef VERILATOR $dumpfile("waveform.fst"); `else $dumpfile("waveform.vcd"); `endif
        $dumpvars();
        for (int i = 0; i < W; i++) prof[i] = 20'd5 + (i % 3);   // noise below threshold
        prof[10] = 900; prof[12] = 800; prof[30] = 700; prof[31] = 700; prof[50] = 950; prof[51] = 400;
        thr = 100;
        repeat (3) @(posedge clk); reset = 0;
        run(1, 5, '{10, 12, 30, 31, 50});      // every local maximum (plateau counts twice)
        run(4, 3, '{10, 30, 50});              // 12 merges into 10 (10 is larger); 31 merges into 30
        if (errors == 0) $display("PASS: peak_pick finds local maxima above thr and merges peaks closer than min_gap");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
