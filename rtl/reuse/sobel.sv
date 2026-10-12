`timescale 1ns/1ps
/*
 * Use two conv3x3 filters to find edges in the image.
 * Gx measures changes from left to right, such as the sides of piano keys.
 * Gy measures changes from top to bottom, such as the ends of keys.
 * Add |Gx| and |Gy| to estimate edge strength without a square root.
 */
module sobel #(
    parameter int W  = 320,
    parameter int H  = 240,
    parameter int DW = 8
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  in_valid,
    input  logic [DW-1:0]         in_pixel,
    input  logic [$clog2(W)-1:0]  in_x,
    input  logic [$clog2(H)-1:0]  in_y,
    output logic                  out_valid,
    output logic [11:0]           out_gx,      // |Gx|, 0..1020
    output logic [11:0]           out_gy,      // |Gy|
    output logic [12:0]           out_mag,     // |Gx| + |Gy|
    output logic [$clog2(W)-1:0]  out_x,
    output logic [$clog2(H)-1:0]  out_y
);
    logic               vx, vy;
    logic signed [11:0] gx, gy;
    logic [$clog2(W)-1:0] x_x; logic [$clog2(H)-1:0] y_x;

    conv3x3 #(.W(W), .H(H), .DW(DW), .OW(12),
              .K('{'{-1, 0, 1}, '{-2, 0, 2}, '{-1, 0, 1}})) u_gx (
        .clk, .reset, .in_valid, .in_pixel, .in_x, .in_y,
        .out_valid(vx), .out_val(gx), .out_x(x_x), .out_y(y_x));
    conv3x3 #(.W(W), .H(H), .DW(DW), .OW(12),
              .K('{'{-1, -2, -1}, '{0, 0, 0}, '{1, 2, 1}})) u_gy (
        .clk, .reset, .in_valid, .in_pixel, .in_x, .in_y,
        .out_valid(vy), .out_val(gy), .out_x(), .out_y());

    logic [11:0] agx, agy;
    assign agx = gx[11] ? 12'(-gx) : 12'(gx);
    assign agy = gy[11] ? 12'(-gy) : 12'(gy);
    always_ff @(posedge clk) begin
        out_valid <= vx & vy & ~reset;
        out_gx    <= agx;
        out_gy    <= agy;
        out_mag   <= 13'(agx) + 13'(agy);
        out_x     <= x_x;
        out_y     <= y_x;
    end
endmodule
