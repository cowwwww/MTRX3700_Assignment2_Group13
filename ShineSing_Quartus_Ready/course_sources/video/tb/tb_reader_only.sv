`timescale 1ns/1ps
// tb_reader_only: the analysis pipeline alone, two sweeps, prints the results. Fast.
module tb_reader_only;
    localparam int W = 320, H = 240, NB = 8, NMAX = 32, XW = $clog2(W);
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1;
    logic [19:0] thr = 20'd16384; logic [XW-1:0] min_gap = 9'd3;   // the board's all-switches-down setting
    logic result_valid, code_valid, prof_wr; logic [$clog2(NMAX):0] edge_count; logic [NMAX*XW-1:0] edge_list;
    logic [NB-1:0] code; logic [XW-1:0] prof_wr_x; logic [19:0] prof_wr_val;
    logic [$clog2(W*H)-1:0] rom_addr; logic [7:0] rom_q;
    image_rom #(.W(W), .H(H), .MIF_FILE("images/barcode.mif"), .HEX_FILE("images/barcode.hex")) u_rom (
        .clk_a(clk), .addr_a(rom_addr), .q_a(rom_q), .clk_b(clk), .addr_b('0), .q_b());
    barcode_reader #(.W(W), .H(H), .NB(NB), .NMAX(NMAX), .GAP(256)) u_reader (
        .clk, .reset, .rom_addr, .rom_q, .thr, .min_gap, .result_valid, .edge_count, .edge_list, .code_valid, .code, .prof_wr, .prof_wr_x, .prof_wr_val);
    int results = 0, expect_code = 8'hA5;
    always @(posedge clk) if (result_valid) begin
        results++;
        $write("result %0d: %0d edges:", results, edge_count);
        for (int i = 0; i < edge_count; i++) $write(" %0d", edge_list[i*XW +: XW]);
        $display("  ->  code %02X (valid=%0d)", code, code_valid);
    end
    // progress
    always @(posedge u_reader.frame_start) $display("sweep starts at %0t", $time);
    always @(posedge u_reader.prof_done)  $display("profile done at %0t", $time);
    always @(posedge u_reader.pick_done)  $display("pick done: %0d peaks", u_reader.count);
    initial begin
        if ($value$plusargs("expect=%h", expect_code)) ;
        repeat (5) @(posedge clk); reset = 0;
        fork
            wait (results == 2);
            begin repeat (400000) @(posedge clk); $display("TIMEOUT"); end
        join_any
        if (results >= 1 && code_valid && code == expect_code) $display("PASS: reader decodes %02X", code);
        else $display("FAILED: results=%0d code=%02X valid=%0d", results, code, code_valid);
        $finish;
    end
endmodule
