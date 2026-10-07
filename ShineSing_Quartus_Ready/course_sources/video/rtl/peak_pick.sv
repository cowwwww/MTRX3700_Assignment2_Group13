`timescale 1ns/1ps
/*
 *  peak_pick.sv -- walk a 1-D profile and list its peaks.
 *
 *  Lesson 4's fft_find_peak returns the single largest bin. This is the plural: every column
 *  that is (a) above a threshold and (b) a local maximum (not smaller than either neighbour)
 *  is a candidate, and candidates closer together than min_gap are merged, the larger winning.
 *  That merge is hysteresis: without it a 3-pixel gap between two piano keys gives two peaks,
 *  one for each side of the gap.
 *
 *  Sequential: `start` begins a walk over x = 0..W-1 reading the profile through rd_x/rd_val
 *  (one-cycle read latency), so it takes about W+3 clocks and no per-pixel logic. Positions
 *  are stored in a small array; `done` pulses at the end with `count` valid. The list is read
 *  combinationally: pos_of(idx).
 */
module peak_pick #(
    parameter int W    = 320,
    parameter int AW   = 20,
    parameter int NMAX = 32
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    start,
    input  logic [AW-1:0]           thr,
    input  logic [$clog2(W)-1:0]    min_gap,
    output logic [$clog2(W)-1:0]    rd_x,
    input  logic [AW-1:0]           rd_val,
    output logic                    busy,       // 1 while walking: rd_x/rd_val then present every entry in order
    output logic                    done,
    output logic [$clog2(NMAX):0]   count,
    input  logic [$clog2(NMAX)-1:0] idx,
    output logic [$clog2(W)-1:0]    pos_of
);
    localparam int XW = $clog2(W);
    logic [XW-1:0] pos [0:NMAX-1];
    assign pos_of = pos[idx];

    typedef enum logic [1:0] {IDLE, WALK, FLUSH, FIN} state_t;
    state_t state;
    logic [XW:0]   x;                 // address being read (one ahead of the value examined)
    logic [AW-1:0] v_prev, v_cur;     // values at x-2 (prev) and x-1 (cur); rd_val is x
    logic [XW-1:0] cur_x;
    logic [XW-1:0] last_pos;
    logic [AW-1:0] last_val;
    logic          have_last;

    // is the value at cur_x a peak?  (neighbour at rd_val is the column after it)
    logic is_peak;
    // TODO 1: a peak is above the threshold AND not smaller than either neighbour: v_prev (the column before)
    //         and rd_val (the column after, just read).
    assign is_peak = 1'b0;

    assign rd_x = x[XW-1:0];
    assign busy = (state == WALK);
    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (reset) begin
            state <= IDLE; count <= '0; x <= '0; have_last <= 1'b0;
        end else case (state)
            IDLE: if (start) begin
                x <= '0; count <= '0; have_last <= 1'b0; v_prev <= '0; v_cur <= '0;
                state <= WALK;
            end
            WALK: begin
                // pipeline: rd_val is the value at x (read last cycle) -> becomes v_cur, and
                // the previous v_cur (at x-1) is examined against its two neighbours.
                x <= x + 1'b1;
                v_prev <= v_cur;
                v_cur  <= rd_val;
                cur_x  <= XW'(x - 1);              // rd_val was read from x-1: v_cur is the value AT cur_x
                if (x >= 3 && is_peak) begin        // examine centre cur_x = x-2 (needs both neighbours)
                    // TODO 2: if there is a previous peak (have_last) and this one is closer to it than min_gap,
                    //         it is the same feature: keep only the larger of the two (replace pos[count-1],
                    //         last_pos and last_val if v_cur > last_val; otherwise ignore this one).
                    // TODO 3: otherwise it is a new peak: if count < NMAX store cur_x in pos[count], increment
                    //         count, and remember it in last_pos / last_val / have_last.

                end
                if (x == W) state <= FIN;                    // last real column examined
            end
            FIN: begin done <= 1'b1; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end
endmodule
