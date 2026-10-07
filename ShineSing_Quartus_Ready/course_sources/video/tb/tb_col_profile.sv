`timescale 1ns/1ps
// tb_col_profile: sum values over rows Y0..Y1 only; a second frame must start from zero (the tag trick).
module tb_col_profile;
    localparam int W = 16, H = 8, Y0 = 2, Y1 = 5;
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1, in_valid = 0, frame_start = 0, done; logic [11:0] in_val; logic [3:0] in_x; logic [2:0] in_y;
    logic [3:0] rd_x; logic [19:0] rd_val;
    col_profile #(.W(W), .H(H), .VW(12), .AW(20), .Y0(Y0), .Y1(Y1)) dut (.*);
    int errors = 0;
    task automatic frame(input int base);
        @(negedge clk); frame_start = 1; @(negedge clk); frame_start = 0;
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) begin
            @(negedge clk); in_valid = 1; in_val = base + x; in_x = x; in_y = y;   // every row adds base+x
        end
        @(negedge clk); in_valid = 0;
    endtask
    task automatic check(input int base);
        repeat (4) @(posedge clk);
        for (int x = 0; x < W; x++) begin
            @(negedge clk); rd_x = x; @(negedge clk);
            if (rd_val != (Y1-Y0+1) * (base + x)) begin errors++; $display("FAIL: column %0d = %0d, expected %0d", x, rd_val, (Y1-Y0+1)*(base+x)); end
        end
    endtask
    int dones = 0; always @(posedge clk) if (done) dones++;
    initial begin
        `ifdef VERILATOR $dumpfile("waveform.fst"); `else $dumpfile("waveform.vcd"); `endif
        $dumpvars();
        repeat (3) @(posedge clk); reset = 0;
        frame(10); check(10);
        frame(3);  check(3);          // smaller values: a stale sum would show as a larger number
        if (dones != 2) begin errors++; $display("FAIL: %0d done pulses, expected 2", dones); end
        if (errors == 0) $display("PASS: col_profile sums rows %0d..%0d only, restarts each frame, done pulses once per frame", Y0, Y1);
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
