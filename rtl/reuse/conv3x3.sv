`timescale 1ns/1ps
/*
 * Apply a 3x3 filter to an image arriving one pixel at a time.
 * Pixels arrive from left to right, then top to bottom, when in_valid is high.
 * Two RAM buffers store the previous rows. Registers keep the previous
 * columns so the filter can use all nine pixels around each centre.
 *
 * Multiply each pixel by its signed weight in K and add the results.
 * Choose OW large enough for the weights; Sobel Gx ranges from -1020 to
 * 1020 with 8-bit pixels.
 *
 * After the bottom-right pixel arrives, two more clock edges produce
 * the result. out_x and out_y give the centre of the window.
 * Skip the outer border, where a full 3x3 window is not available.
 */
module conv3x3 #(
    parameter int W  = 320,
    parameter int H  = 240,
    parameter int DW = 8,            // pixel width
    parameter int OW = 12,           // output width (signed)
    parameter logic signed [7:0] K [0:2][0:2] = '{'{-1, 0, 1}, '{-2, 0, 2}, '{-1, 0, 1}}   // Sobel Gx
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  in_valid,
    input  logic [DW-1:0]         in_pixel,
    input  logic [$clog2(W)-1:0]  in_x,
    input  logic [$clog2(H)-1:0]  in_y,
    output logic                  out_valid,
    output logic signed [OW-1:0]  out_val,
    output logic [$clog2(W)-1:0]  out_x,
    output logic [$clog2(H)-1:0]  out_y
);
    // Use sync_ram to store the previous two rows in M10K memory.
    // This avoids using large numbers of registers for the row buffers.
    logic [DW-1:0] lb1_q, lb2_q;
    logic          lb2_we;
    logic [$clog2(W)-1:0] lb2_waddr;

    // Reading and writing the same column returns the old pixel from row y-1.
    sync_ram #(.WIDTH(DW), .DEPTH(W), .AW($clog2(W))) linebuf1 (
        .clk(clk), .we(in_valid),
        .waddr(in_x), .raddr(in_x), .wdata(in_pixel), .rdata(lb1_q));

    // Copy the previous row into lb2 one clock later, using the delayed address.
    // Read lb2 at the current column to get the pixel from row y-2.
    always_ff @(posedge clk) begin
        lb2_we    <= in_valid & ~reset;
        lb2_waddr <= in_x;
    end
    sync_ram #(.WIDTH(DW), .DEPTH(W), .AW($clog2(W))) linebuf2 (
        .clk(clk), .we(lb2_we),
        .waddr(lb2_waddr), .raddr(in_x), .wdata(lb1_q), .rdata(lb2_q));

    // Stage 1: line up the current pixel with the two buffered row pixels.
    logic                  s1_valid;
    logic [DW-1:0]         s1_pix;
    logic [$clog2(W)-1:0]  s1_x;
    logic [$clog2(H)-1:0]  s1_y;
    always_ff @(posedge clk) begin
        s1_valid <= in_valid & ~reset;
        s1_pix   <= in_pixel;
        s1_x     <= in_x;
        s1_y     <= in_y;
    end
    // These three pixels come from rows y-2, y-1 and y at column s1_x.
    logic [DW-1:0] c_top, c_mid, c_bot;
    assign c_top = lb2_q;
    assign c_mid = lb1_q;
    assign c_bot = s1_pix;

    // Stage 2: keep three columns to form the 3x3 window.
    logic [DW-1:0] w [0:2][0:2];             // w[row][col]: col 0 = x-2, col 1 = x-1, col 2 = x
    logic                  s2_valid;
    logic [$clog2(W)-1:0]  s2_x;
    logic [$clog2(H)-1:0]  s2_y;
    always_ff @(posedge clk) begin
        s2_valid <= s1_valid;
        s2_x     <= s1_x;
        s2_y     <= s1_y;
        if (s1_valid) begin
            // Shift each row left and put the new pixels in the right-hand column.
            for (int r = 0; r < 3; r++) begin
                w[r][0] <= w[r][1];
                w[r][1] <= w[r][2];
            end
            w[0][2] <= c_top;
            w[1][2] <= c_mid;
            w[2][2] <= c_bot;
        end
    end

    // Stage 3: calculate the weighted sum and output complete windows.
    logic signed [OW-1:0] acc;
    always_comb begin
        acc = '0;
        // Keep pixels positive when converting to signed values.
        // Widen pixels and weights to OW bits before multiplying.
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < 3; c++)
                acc += OW'($signed(K[r][c])) * OW'($signed({1'b0, w[r][c]}));
    end
    always_ff @(posedge clk) begin
        // Output only when three rows and three columns have arrived.
        // The centre is one row and one column behind the latest pixel.
        out_valid <= !reset && s2_valid && (s2_x >= 2) && (s2_y >= 2);
        out_val   <= acc;
        out_x     <= s2_x - 1'b1;
        out_y     <= s2_y - 1'b1;
    end
endmodule
