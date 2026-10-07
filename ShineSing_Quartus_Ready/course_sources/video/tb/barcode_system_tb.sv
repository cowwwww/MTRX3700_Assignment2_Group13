`timescale 1ns/1ps
/*
 *  barcode_system_tb: the whole reader. Analysis at 50 MHz on images/barcode.hex, results through
 *  cdc_latch into the 25 MHz display, one 640x480 frame captured by the VGA monitor model
 *  (frame_1.ppm -> tools/render_frames.py -> frame_1.png). Checks the decoded value against
 *  +expect=<hex> (default A5) and prints the edges found.
 */
module barcode_system_tb #(parameter int H_RES = 640, V_RES = 480,   // ModelSim: -gH_RES=160 -gV_RES=120 for speed
                           parameter string MIF_FILE = "images/barcode.mif", HEX_FILE = "images/barcode.hex");
    localparam int W = 320, H = 240, NB = 8, NMAX = 32, XW = $clog2(W);
    logic clk50 = 0; always #10 clk50 = ~clk50;
    logic clk25 = 0; always #20 clk25 = ~clk25;
    logic reset = 1;

    logic [19:0] thr = 20'd16384; logic [XW-1:0] min_gap = 9'd3;   // the board's all-switches-down setting
    logic result_valid, code_valid, prof_wr; logic [$clog2(NMAX):0] edge_count; logic [NMAX*XW-1:0] edge_list;
    logic [NB-1:0] code; logic [XW-1:0] prof_wr_x; logic [19:0] prof_wr_val;
    logic [$clog2(W*H)-1:0] ra_addr, rb_addr; logic [7:0] ra_q, rb_q;
    image_rom #(.W(W), .H(H), .MIF_FILE(MIF_FILE), .HEX_FILE(HEX_FILE)) u_rom (.clk_a(clk50), .addr_a(ra_addr), .q_a(ra_q), .clk_b(clk25), .addr_b(rb_addr), .q_b(rb_q));
    barcode_reader #(.W(W), .H(H), .NB(NB), .NMAX(NMAX), .GAP(256)) u_reader (
        .clk(clk50), .reset, .rom_addr(ra_addr), .rom_q(ra_q), .thr, .min_gap, .result_valid, .edge_count, .edge_list, .code_valid, .code,
        .prof_wr, .prof_wr_x, .prof_wr_val);

    localparam int RW = 1 + $clog2(NMAX)+1 + NMAX*XW + NB;
    logic [RW-1:0] bundle_src, bundle_dst; logic vblank, updated;
    assign bundle_src = {code_valid, edge_count, edge_list, code};
    cdc_latch #(.WIDTH(RW)) u_latch (.src_clk(clk50), .src_valid(result_valid), .src_data(bundle_src), .src_busy(),
        .dst_clk(clk25), .dst_reset(reset), .update_ok(vblank), .dst_data(bundle_dst), .dst_updated(updated));
    logic d_code_valid; logic [$clog2(NMAX):0] d_count; logic [NMAX*XW-1:0] d_list; logic [NB-1:0] d_code;
    assign {d_code_valid, d_count, d_list, d_code} = bundle_dst;

    logic [29:0] data; logic sop, eop, valid, ready;
    display #(.H_RES(H_RES), .V_RES(V_RES), .W(W), .H(H), .NB(NB), .NMAX(NMAX)) u_display (
        .clk(clk25), .reset, .view_profile(1'b1), .rom_addr(rb_addr), .grey(rb_q),
        .edge_count(d_count), .edge_list(d_list), .code_valid(d_code_valid), .code(d_code),
        .prof_wr_clk(clk50), .prof_wr, .prof_wr_x, .prof_wr_val,
        .data, .startofpacket(sop), .endofpacket(eop), .valid, .ready, .vblank);
    int frames_done, errors, x_pos, y_pos; logic accept, discard;
    vga_monitor_model #(.H_RES(H_RES), .V_RES(V_RES), .H_BLANK(H_RES/4), .V_BLANK(V_RES/10), .ASCII_ART(0), .PPM_PREFIX("frame"), .MAX_PPM_FILES(3), .VERBOSE(0)) u_mon (
        .clk(clk25), .reset, .data, .startofpacket(sop), .endofpacket(eop), .valid, .ready,
        .frames_done, .errors, .x_pos, .y_pos, .accept, .discard);

    int expect_code = 8'hA5, fails = 0, results = 0;
    always @(posedge clk50) if (result_valid) begin
        results++;
        $write("result %0d: %0d edges:", results, edge_count);
        for (int i = 0; i < edge_count; i++) $write(" %0d", edge_list[i*XW +: XW]);
        $display("  ->  code %02X (valid=%0d)", code, code_valid);
    end
    initial begin
        if ($value$plusargs("expect=%h", expect_code)) ;
        `ifdef VERILATOR
        if ($test$plusargs("wave")) begin $dumpfile("waveform.fst"); $dumpvars(); end
        `else
        $dumpfile("waveform.vcd"); $dumpvars(0, u_reader.u_pick); $dumpvars(0, u_latch);
        `endif
        repeat (5) @(posedge clk50); reset = 0;
        // one analysis sweep is W*H clocks; wait for two results so the second is from a clean profile
        wait (results == 2);
        if (!code_valid || code != expect_code) begin fails++; $display("FAIL: code %02X valid=%0d, expected %02X", code, code_valid, expect_code); end
        // now a display frame that includes the latched result
        wait (updated); $display("display: results latched in blanking at frame %0d", frames_done);
        wait (frames_done >= 3);
        if (errors != 0) begin fails++; $display("FAIL: monitor model counted %0d protocol errors", errors); end
        if (d_code != code) begin fails++; $display("FAIL: display holds %02X, reader produced %02X", d_code, code); end
        if (fails == 0) $display("PASS: barcode read as %02X, %0d edges, results crossed to the display in blanking, %0d frames drawn", code, edge_count, frames_done);
        else $display("FAILED: %0d problems", fails);
        $finish;
    end
endmodule
