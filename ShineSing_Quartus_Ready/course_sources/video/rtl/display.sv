`timescale 1ns/1ps
/*
 *  display.sv -- the picture on the monitor, with the reader's findings drawn over it.
 *
 *  An Avalon-ST video source exactly like Lesson 3's vga_face: a pixel index that advances on
 *  every valid&ready handshake, a ROM read one handshake ahead, 30-bit RGB out. The stored
 *  picture is 320x240; each stored pixel is shown as a 2x2 block (x>>1, y>>1), which is all the
 *  "scaler" is.
 *
 *  Overlay (view 0): every detected edge is a thin red line, and every decoded bar is tinted
 *  green (a 1) or blue (a 0). View 1 adds the column profile as a yellow bar graph along the
 *  bottom, drawn from a copy of the profile that the analysis clock writes and this clock
 *  reads: the profile view is a debugging tool, and this is the one place a frame may show a
 *  half-updated value (the edge list and code, which matter, come through cdc_latch).
 */
module display #(
    parameter int    H_RES    = 640,
    parameter int    V_RES    = 480,
    parameter int    W        = 320,          // stored picture
    parameter int    H        = 240,
    parameter int    NB       = 8,
    parameter int    NMAX     = 32
) (
    input  logic                       clk,           // pixel clock
    input  logic                       reset,
    input  logic                       view_profile,  // SW1
    // the picture: one read port of the image ROM (address out, pixel back one clock later)
    output logic [$clog2(W*H)-1:0]     rom_addr,
    input  logic [7:0]                 grey,
    // results (already in this clock domain, via cdc_latch)
    input  logic [$clog2(NMAX):0]      edge_count,
    input  logic [NMAX*$clog2(W)-1:0]  edge_list,
    input  logic                       code_valid,
    input  logic [NB-1:0]              code,
    // the profile copy (written from the analysis clock)
    input  logic                       prof_wr_clk,
    input  logic                       prof_wr,
    input  logic [$clog2(W)-1:0]       prof_wr_x,
    input  logic [19:0]                prof_wr_val,
    // Avalon-ST
    output logic [29:0]                data,
    output logic                       startofpacket,
    output logic                       endofpacket,
    output logic                       valid,
    input  logic                       ready,
    output logic                       vblank          // 1 between frames: safe to update results
);
    localparam int XW = $clog2(W);
    localparam int NumPixels = H_RES * V_RES;

    // ---- raster position, one ahead for the ROM read ----
    logic [$clog2(H_RES)-1:0] x, x_next;
    logic [$clog2(V_RES)-1:0] y, y_next;
    logic last_pixel;
    assign last_pixel = (x == H_RES-1) && (y == V_RES-1);
    always_comb begin
        if (reset || last_pixel) begin x_next = '0; y_next = '0; end
        else if (x == H_RES-1) begin x_next = '0; y_next = y + 1'b1; end
        else begin x_next = x + 1'b1; y_next = y; end
    end
    logic read_enable;
    assign read_enable = reset | (valid & ready);
    assign rom_addr = ($clog2(W*H))'(y_next >> 1) * W + ($clog2(W*H))'(x_next >> 1);
    // the ROM output is registered inside image_rom on every clock; hold it when there is no handshake
    logic [7:0] grey_held; logic held_valid;
    always_ff @(posedge clk) begin
        if (read_enable) begin x <= x_next; y <= y_next; grey_held <= grey; held_valid <= 1'b1; end
    end
    // NOTE: image_rom reads every clock, so `grey` follows rom_addr with one cycle of latency; since
    // rom_addr only changes on read_enable, grey is right whenever we present the pixel.

    // ---- profile copy: written by the analysis clock, read here ----
    logic [19:0] prof [0:W-1];
    always_ff @(posedge prof_wr_clk) if (prof_wr) prof[prof_wr_x] <= prof_wr_val;
    logic [19:0] prof_q;
    always_ff @(posedge clk) prof_q <= prof[x_next >> 1];

    // ---- overlay ----
    logic [XW-1:0] cx;  assign cx = XW'(x >> 1);
    logic on_edge, in_bar, bar_bit;
    always_comb begin
        on_edge = 1'b0; in_bar = 1'b0; bar_bit = 1'b0;
        for (int i = 0; i < NMAX; i++) begin
            if (i < edge_count && edge_list[i*XW +: XW] == cx) on_edge = 1'b1;
        end
        if (code_valid) for (int b = 0; b < NB; b++) begin
            if (cx >= edge_list[(2*b)*XW +: XW] && cx < edge_list[(2*b+1)*XW +: XW]) begin
                in_bar = 1'b1; bar_bit = code[NB-1-b];
            end
        end
    end
    logic [7:0] r, g, b;
    logic [7:0] bar_h;                                   // profile bar height in rows (0..79)
    assign bar_h = 8'(prof_q >> 11);
    always_comb begin
        {r, g, b} = {grey, grey, grey};
        if (in_bar) begin
            if (bar_bit) begin r = grey - (grey >> 2); g = (grey > 8'hA0) ? 8'hFF : grey + 8'h50; b = grey - (grey >> 2); end   // 1: a green cast
            else         begin r = grey - (grey >> 2); g = grey - (grey >> 2); b = (grey > 8'h90) ? 8'hFF : grey + 8'h60; end   // 0: a blue cast
        end
        if (on_edge) begin r = 8'hFF; g = 8'h30; b = 8'h30; end
        if (view_profile && y >= V_RES-80 && (V_RES-1-y) < bar_h) begin r = 8'hFF; g = 8'hD0; b = 8'h20; end
    end
    assign data = {r, 2'b00, g, 2'b00, b, 2'b00};
    assign valid = ~reset;
    assign startofpacket = (x == 0) && (y == 0);
    assign endofpacket   = last_pixel;
    assign vblank        = (y == 0) && (x < 8);           // a short window at the top of each frame
endmodule
