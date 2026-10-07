`timescale 1ns/1ps
/*
 *  barcode_reader.sv -- the analysis pipeline, all in one clock domain (50 MHz on the board):
 *
 *      image ROM -> raster_source -> sobel -> col_profile -> peak_pick -> bar_decode
 *
 *  It sweeps the picture continuously (one sweep = W*H clocks, about 1.5 ms at 50 MHz, then a
 *  pause), and after each sweep publishes: the edge positions it found, how many, the decoded
 *  value, and whether the decode was valid. `result_valid` pulses when a new result is ready;
 *  the results are stable until the next pulse, which is what cdc_latch needs.
 *
 *  The threshold and minimum spacing come in from outside (switches, or constants) so that
 *  the effect of changing them can be watched on the profile view.
 */
module barcode_reader #(
    parameter int    W        = 320,
    parameter int    H        = 240,
    parameter int    NB       = 8,
    parameter int    NMAX     = 32,
    parameter int    Y0       = 60,       // rows summed into the profile
    parameter int    Y1       = 180,
    parameter int    GAP      = 2048
) (
    input  logic                     clk,
    input  logic                     reset,
    // the picture: one read port of the image ROM (address out, pixel back one clock later)
    output logic [$clog2(W*H)-1:0]   rom_addr,
    input  logic [7:0]               rom_q,
    input  logic [19:0]              thr,          // profile threshold
    input  logic [$clog2(W)-1:0]     min_gap,      // minimum spacing between edges
    output logic                     result_valid,
    output logic [$clog2(NMAX):0]    edge_count,
    output logic [NMAX*$clog2(W)-1:0] edge_list,   // packed positions, entry 0 in the low bits
    output logic                     code_valid,
    output logic [NB-1:0]            code,
    // the profile, for the display's profile view (read in another clock via prof_* below)
    output logic                     prof_wr,
    output logic [$clog2(W)-1:0]     prof_wr_x,
    output logic [19:0]              prof_wr_val
);
    localparam int XW = $clog2(W);

    // ---- picture sweep ----
    logic frame_start, px_valid; logic [7:0] px; logic [XW-1:0] px_x; logic [$clog2(H)-1:0] px_y;
    raster_source #(.W(W), .H(H), .GAP(GAP)) u_src (.clk, .reset, .rom_addr, .rom_q, .frame_start,
        .out_valid(px_valid), .out_pixel(px), .out_x(px_x), .out_y(px_y));

    // ---- edges ----
    logic e_valid; logic [11:0] e_gx, e_gy; logic [12:0] e_mag; logic [XW-1:0] e_x; logic [$clog2(H)-1:0] e_y;
    sobel #(.W(W), .H(H)) u_sobel (.clk, .reset, .in_valid(px_valid), .in_pixel(px), .in_x(px_x), .in_y(px_y),
        .out_valid(e_valid), .out_gx(e_gx), .out_gy(e_gy), .out_mag(e_mag), .out_x(e_x), .out_y(e_y));

    // ---- column profile of |Gx| over rows Y0..Y1 ----
    logic prof_done; logic [XW-1:0] prof_rd_x; logic [19:0] prof_rd_val;
    col_profile #(.W(W), .H(H), .VW(12), .AW(20), .Y0(Y0), .Y1(Y1), .X_LAST(W-2)) u_prof (.clk, .reset,
        .in_valid(e_valid), .in_val(e_gx), .in_x(e_x), .in_y(e_y), .frame_start,
        .done(prof_done), .rd_x(prof_rd_x), .rd_val(prof_rd_val));

    // ---- peaks -> edge list ----
    logic pick_done; logic [$clog2(NMAX):0] count; logic [$clog2(NMAX)-1:0] pk_idx; logic [XW-1:0] pk_pos;
    logic pick_busy;
    peak_pick #(.W(W), .AW(20), .NMAX(NMAX)) u_pick (.clk, .reset, .start(prof_done), .thr, .min_gap,
        .rd_x(prof_rd_x), .rd_val(prof_rd_val), .busy(pick_busy), .done(pick_done), .count, .idx(pk_idx), .pos_of(pk_pos));

    // ---- decode ----
    logic dec_done, dec_valid; logic [NB-1:0] dec_value; logic [$clog2(NMAX)-1:0] dec_idx;
    bar_decode #(.W(W), .NB(NB), .NMAX(NMAX)) u_dec (.clk, .reset, .start(pick_done), .count,
        .idx(dec_idx), .pos_of(pk_pos), .done(dec_done), .valid(dec_valid), .value(dec_value));

    // the decoder owns the list-read port while it runs; afterwards we copy the list out
    typedef enum logic [1:0] {RUN, COPY, PUBLISH} st_t;
    st_t st; logic [$clog2(NMAX)-1:0] cp_i;
    assign pk_idx = (st == COPY) ? cp_i : dec_idx;
    logic [NMAX*XW-1:0] list_q;
    always_ff @(posedge clk) begin
        result_valid <= 1'b0;
        if (reset) begin st <= RUN; cp_i <= '0; end
        else case (st)
            RUN: if (dec_done) begin cp_i <= '0; st <= COPY; end
            COPY: begin
                list_q[cp_i*XW +: XW] <= (cp_i < count) ? pk_pos : '0;
                if (cp_i == NMAX-1) st <= PUBLISH; else cp_i <= cp_i + 1'b1;
            end
            PUBLISH: begin
                edge_list <= list_q; edge_count <= count; code <= dec_value; code_valid <= dec_valid;
                result_valid <= 1'b1; st <= RUN;
            end
            default: st <= RUN;
        endcase
    end

    // The picker's walk presents every profile entry in order on (rd_x, rd_val), one cycle apart:
    // tap it, so the display can keep a copy of the finished profile for its profile view.
    logic busy_d; logic [XW-1:0] rd_x_d;
    always_ff @(posedge clk) begin
        busy_d <= pick_busy; rd_x_d <= prof_rd_x;
        prof_wr <= busy_d; prof_wr_x <= rd_x_d; prof_wr_val <= prof_rd_val;
    end
endmodule
