`timescale 1ns/1ps
// tb_bar_decode: 8 bars with widths narrow=6 / wide=12 encoding 0xA5 -> value 0xA5; wrong edge count -> invalid.
module tb_bar_decode;
    localparam int W = 320, NB = 8, NMAX = 32;
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1, start = 0, done, valid; logic [5:0] count; logic [4:0] idx; logic [8:0] pos_of; logic [7:0] value;
    logic [8:0] pos [0:NMAX-1];
    assign pos_of = pos[idx];
    bar_decode #(.W(W), .NB(NB), .NMAX(NMAX)) dut (.*);
    int errors = 0;
    initial begin
        `ifdef VERILATOR $dumpfile("waveform.fst"); `else $dumpfile("waveform.vcd"); `endif
        $dumpvars();
        // edges of 0xA5 = 1010 0101, narrow 6, wide 12, space 6, starting at 103 (as make_barcode.py lays it out)
        begin automatic int e[16] = '{103,115,121,127,133,145,151,157,163,169,175,187,193,199,205,217};
              for (int i = 0; i < 16; i++) pos[i] = e[i]; end
        count = 16;
        repeat (3) @(posedge clk); reset = 0;
        @(negedge clk); start = 1; @(negedge clk); start = 0; wait (done); @(negedge clk);
        if (!valid || value != 8'hA5) begin errors++; $display("FAIL: decoded %02X valid=%0d, expected A5", value, valid); end
        count = 15; @(negedge clk); start = 1; @(negedge clk); start = 0; wait (done); @(negedge clk);
        if (valid) begin errors++; $display("FAIL: 15 edges decoded as valid"); end
        if (errors == 0) $display("PASS: bar_decode reads 0xA5 from 16 edges and rejects a wrong edge count");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
