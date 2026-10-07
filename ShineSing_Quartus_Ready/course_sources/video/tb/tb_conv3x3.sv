`timescale 1ns/1ps
// tb_conv3x3: a 16x12 picture, dark on the left, bright on the right (a vertical edge at x=8).
// Sobel Gx must be +4*(bright-dark) at centre columns 7 and 8, 0 elsewhere; interior only; coordinates carried.
module tb_conv3x3;
    localparam int W = 16, H = 12;
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1, in_valid = 0; logic [7:0] in_pixel; logic [3:0] in_x; logic [3:0] in_y;
    logic out_valid; logic signed [11:0] out_val; logic [3:0] out_x, out_y;
    conv3x3 #(.W(W), .H(H)) dut (.*);
    int errors = 0, outputs = 0;
    function automatic logic [7:0] pix(int x, int y); return (x < 8) ? 8'd40 : 8'd200; endfunction
    // checker
    always @(posedge clk) if (out_valid) begin : chk
        int expect_v;
        outputs++;
        expect_v = (out_x == 7 || out_x == 8) ? 4 * (200 - 40) : 0;
        if (out_val != expect_v) begin errors++; if (errors < 8) $display("FAIL: centre (%0d,%0d) got %0d expected %0d", out_x, out_y, out_val, expect_v); end
        if (out_x < 1 || out_x > W-2 || out_y < 1 || out_y > H-2) begin errors++; $display("FAIL: border centre (%0d,%0d) was output", out_x, out_y); end
    end
    initial begin
        `ifdef VERILATOR $dumpfile("waveform.fst"); `else $dumpfile("waveform.vcd"); `endif
        $dumpvars();
        repeat (3) @(posedge clk); reset = 0;
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) begin
            @(negedge clk); in_valid = 1; in_pixel = pix(x, y); in_x = x; in_y = y;
            if (x == W-1 && y % 3 == 0) begin @(negedge clk); in_valid = 0; end   // a gap now and then: must not matter
        end
        @(negedge clk); in_valid = 0; repeat (6) @(posedge clk);
        if (outputs != (W-2)*(H-2)) begin errors++; $display("FAIL: %0d outputs, expected %0d", outputs, (W-2)*(H-2)); end
        if (errors == 0) $display("PASS: conv3x3 Sobel Gx on a vertical edge, %0d interior outputs, coordinates correct", outputs);
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
