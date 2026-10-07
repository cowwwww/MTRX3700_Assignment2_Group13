`timescale 1ns/1ps
/*
 *  top_level.sv -- the barcode reader on the DE1-SoC.
 *
 *    CLOCK_50 --> barcode_reader (analysis: ROM sweep, Sobel, profile, peaks, decode)
 *                       | cdc_latch (results, updated in vertical blanking)
 *                       v
 *    video_pll --> display (Avalon-ST source, overlay) --> vga_sink.qsys (VGA Controller) --> monitor
 *
 *  SW0: picture 0 (clean, 0xA5) or picture 1 (photo-like: noise, a lighting gradient, blur; 0x3C).
 *  HEX1..HEX0: the decoded value (hex).  HEX3..HEX2: number of edges found (decimal).  HEX5: 'd' when
 *  the decode is valid.  SW1: profile view.  SW9..SW4: threshold (x 2048).  SW3..SW2: min gap 2/4/6/8.
 *  KEY0 (active low): reset.
 */
module top_level (
    input  wire        CLOCK_50,
    input  wire [9:0]  SW,
    input  wire [3:0]  KEY,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output wire [9:0]  LEDR,
    output wire        VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N,
    output wire [7:0]  VGA_R, VGA_G, VGA_B
);
    localparam int W = 320, H = 240, NB = 8, NMAX = 32, XW = $clog2(W);

    wire clk_25, pll_locked;
    video_pll video_pll_u (.refclk(CLOCK_50), .rst(1'b0), .outclk_0(clk_25), .locked(pll_locked));

    // ---- reset: KEY0, synchronised into each domain ----
    logic [1:0] rs50, rs25;
    always_ff @(posedge CLOCK_50) rs50 <= {rs50[0], ~KEY[0]};
    always_ff @(posedge clk_25)   rs25 <= {rs25[0], ~KEY[0] | ~pll_locked};
    wire reset50 = rs50[1], reset25 = rs25[1];

    // ---- analysis at 50 MHz ----
    // switches all down is a setting that works on both pictures; the switches move away from it
    logic [19:0] thr; assign thr = {SW[9:4], 11'd0} + 20'd16384;     // 16384 + SW9..4 x 2048  (noise ~3500, dim edges ~30000, clean edges ~70000)
    logic [XW-1:0] min_gap; assign min_gap = XW'({SW[3:2], 1'b0}) + XW'(3);   // 3, 5, 7, 9  (blurred edges 3-4 px wide; narrow bars 6 px)
    logic result_valid, code_valid, prof_wr;
    logic [$clog2(NMAX):0] edge_count; logic [NMAX*XW-1:0] edge_list; logic [NB-1:0] code;
    logic [XW-1:0] prof_wr_x; logic [19:0] prof_wr_val;
    // ---- the two pictures: one ROM each, port A read by the analysis, port B by the display; SW0 picks ----
    logic [$clog2(W*H)-1:0] ra_addr, rb_addr; logic [7:0] qa0, qa1, qb0, qb1, ra_q, rb_q;
    image_rom #(.W(W), .H(H), .MIF_FILE("images/barcode.mif"),  .HEX_FILE("images/barcode.hex"))  u_rom0 (.clk_a(CLOCK_50), .addr_a(ra_addr), .q_a(qa0), .clk_b(clk_25), .addr_b(rb_addr), .q_b(qb0));
    image_rom #(.W(W), .H(H), .MIF_FILE("images/barcode2.mif"), .HEX_FILE("images/barcode2.hex")) u_rom1 (.clk_a(CLOCK_50), .addr_a(ra_addr), .q_a(qa1), .clk_b(clk_25), .addr_b(rb_addr), .q_b(qb1));
    logic [1:0] sel50, sel25;                                          // SW0 synchronised into each clock
    always_ff @(posedge CLOCK_50) sel50 <= {sel50[0], SW[0]};
    always_ff @(posedge clk_25)   sel25 <= {sel25[0], SW[0]};
    assign ra_q = sel50[1] ? qa1 : qa0;
    assign rb_q = sel25[1] ? qb1 : qb0;

    barcode_reader #(.W(W), .H(H), .NB(NB), .NMAX(NMAX)) u_reader (
        .clk(CLOCK_50), .reset(reset50), .rom_addr(ra_addr), .rom_q(ra_q), .thr, .min_gap,
        .result_valid, .edge_count, .edge_list, .code_valid, .code,
        .prof_wr, .prof_wr_x, .prof_wr_val);

    // ---- results into the pixel clock, only during vertical blanking ----
    localparam int RW = 1 + $clog2(NMAX)+1 + NMAX*XW + NB;
    logic [RW-1:0] bundle_src, bundle_dst; logic vblank, updated;
    assign bundle_src = {code_valid, edge_count, edge_list, code};
    cdc_latch #(.WIDTH(RW)) u_latch (.src_clk(CLOCK_50), .src_valid(result_valid), .src_data(bundle_src), .src_busy(),
        .dst_clk(clk_25), .dst_reset(reset25), .update_ok(vblank), .dst_data(bundle_dst), .dst_updated(updated));
    logic d_code_valid; logic [$clog2(NMAX):0] d_count; logic [NMAX*XW-1:0] d_list; logic [NB-1:0] d_code;
    assign {d_code_valid, d_count, d_list, d_code} = bundle_dst;

    // ---- display at 25 MHz ----
    logic [29:0] st_data; logic st_sop, st_eop, st_valid, st_ready;
    display #(.W(W), .H(H), .NB(NB), .NMAX(NMAX)) u_display (
        .clk(clk_25), .reset(reset25), .view_profile(SW[1]), .rom_addr(rb_addr), .grey(rb_q),
        .edge_count(d_count), .edge_list(d_list), .code_valid(d_code_valid), .code(d_code),
        .prof_wr_clk(CLOCK_50), .prof_wr, .prof_wr_x, .prof_wr_val,
        .data(st_data), .startofpacket(st_sop), .endofpacket(st_eop), .valid(st_valid), .ready(st_ready), .vblank);

    vga_sink u_vga (
        .clk_clk(clk_25), .reset_reset_n(~reset25),
        .video_in_data(st_data), .video_in_startofpacket(st_sop), .video_in_endofpacket(st_eop),
        .video_in_valid(st_valid), .video_in_ready(st_ready),
        .vga_CLK(VGA_CLK), .vga_HS(VGA_HS), .vga_VS(VGA_VS), .vga_BLANK(VGA_BLANK_N), .vga_SYNC(VGA_SYNC_N),
        .vga_R(VGA_R), .vga_G(VGA_G), .vga_B(VGA_B));

    // ---- displays: the value and the edge count, in the 50 MHz domain (quasi-static) ----
    hex_seg h0 (.d(code[3:0]),       .blank(1'b0), .seg(HEX0));
    hex_seg h1 (.d(code[7:4]),       .blank(1'b0), .seg(HEX1));
    wire [3:0] ec_tens = 4'(edge_count / 10), ec_ones = 4'(edge_count % 10);     // edges found, in decimal
    hex_seg h2 (.d(ec_ones), .blank(1'b0), .seg(HEX2));
    hex_seg h3 (.d(ec_tens), .blank(ec_tens == 0), .seg(HEX3));
    hex_seg h4 (.d(4'h0), .blank(1'b1), .seg(HEX4));
    hex_seg h5 (.d(4'hD), .blank(~code_valid), .seg(HEX5));
    assign LEDR = {code_valid, updated, SW[9:2]};
endmodule
