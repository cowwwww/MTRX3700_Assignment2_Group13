`timescale 1ns/1ps
/*
 *  classifier.sv -- nearest-template classifier with a vote and a "don't know" (PROVIDED for A2).
 *
 *  Interface (the same at every rung; only D changes):
 *      feature[D-1:0] of FW-bit unsigned words + feature_valid, once per frame
 *      -> result (0..NCLASS-1), confidence (0..255), result_valid (a pulse per frame), reject
 *
 *  Inside:
 *   1. Distance to every template: d(t) = sum over i of |feature[i] - T[t][i]|   (sum of absolute
 *      differences: a subtract, an absolute value and an add per feature; no multiplier).
 *      Templates are a constant array in templates.svh (written by tools/train_templates.py). There are NT templates per class (NT x NCLASS in all).
 *   2. The nearest template wins; its class is the frame's raw answer. Its distance d1, and the best
 *      distance among the OTHER classes d2, give the confidence: reject if d1 > DMAX or if
 *      d1 * RHO_DEN > d2 * RHO_NUM  (i.e. d1/d2 > rho: two classes almost equally near).
 *   3. Majority vote over the last M raw answers (rejected frames do not vote).
 *
 *  Sequential: one template per clock, so a frame costs NT*NCLASS*D clocks at most (with D=24,
 *  NT=4, NCLASS=4: 384 clocks against a budget of a million). result_valid pulses when done.
 *  Confidence = 255 * (1 - d1/d2), clipped; 0 when rejected.
 */
module classifier #(
    parameter int    D             = 8,        // features per frame
    parameter int    FW            = 16,       // feature width (unsigned)
    parameter int    NCLASS        = 4,
    parameter int    NT            = 4,        // templates per class
    parameter int    M             = 5,        // vote length (odd)
    parameter int    DMAX          = 65535,    // reject if nearest distance exceeds this
    parameter int    RHO_NUM       = 7,        // reject if d1/d2 > RHO_NUM/RHO_DEN
    parameter int    RHO_DEN       = 10
) (
    input  logic                     clk,
    input  logic                     reset,
    input  logic                     enable,          // the gate: classify only while open
    input  logic                     feature_valid,
    input  logic [D-1:0][FW-1:0]     feature,
    input  logic                     enrol,
    input  logic [1:0]               enrol_class,
    output logic [NCLASS-1:0]        trained,
    output logic [$clog2(NCLASS)-1:0] result,      // voted class
    output logic [7:0]               confidence,
    output logic                     reject,          // this frame's raw answer was rejected
    output logic                     result_valid      // pulse: result/confidence updated
);
    localparam int NTT = NCLASS * NT;
    localparam int DW  = FW + $clog2(D) + 1;          // distance width
    // The templates: a constant array from templates.svh, written by tools/train_templates.py
    // (an include file rather than $readmemh, so Quartus and the simulators see the same ROM).
    // Train the supplied classifier with samples from the board.
    // Reset clears the saved training samples.
    logic [D-1:0][FW-1:0] templ [0:NTT-1];
    integer enrol_count[0:NCLASS-1];

    typedef enum logic [2:0] {IDLE, DIST, DECIDE, CONFIDENCE, VOTE} st_t;
    st_t st;
    logic [$clog2(NTT)-1:0] t;
    logic [D-1:0][FW-1:0] f_q;
    logic [DW-1:0] d1, d2, sad;
    logic [$clog2(NCLASS)-1:0] best_class, raw_class;
    logic [$clog2(NCLASS)-1:0] votes [0:M-1];
    logic [M-1:0] vote_ok;
    logic [$clog2(M):0] vptr;
    logic [DW:0] remainder, doubled;
    logic [7:0] ratio;
    logic [3:0] ratio_bit;
    assign doubled=remainder<<1;

    // distance to template t (combinational over D words: D subtract/abs/add = fine for D <= 32)
    always_comb begin
        sad = '0;
        for (int i = 0; i < D; i++)
            sad += (f_q[i] > templ[t][i]) ? DW'(f_q[i] - templ[t][i]) : DW'(templ[t][i] - f_q[i]);
    end
    logic [$clog2(NCLASS)-1:0] t_class;
    assign t_class = ($clog2(NCLASS))'(t / NT);

    // ---- vote ----
    logic [$clog2(M):0] tally [0:NCLASS-1];
    always_comb begin
        for (int c = 0; c < NCLASS; c++) begin
            tally[c] = '0;
            for (int k = 0; k < M; k++) if (vote_ok[k] && votes[k] == c) tally[c]++;
        end
    end
    logic [$clog2(NCLASS)-1:0] winner;
    always_comb begin
        winner = '0;
        for (int c = 1; c < NCLASS; c++) if (tally[c] > tally[winner]) winner = c;
    end

    logic rej_c;
    assign rej_c = (d2 == 0) || (d1 > DMAX) || (64'(d1) * RHO_DEN > 64'(d2) * RHO_NUM);
    logic [$clog2(M)-1:0] vidx;
    assign vidx = vptr[$clog2(M)-1:0];
    always_ff @(posedge clk) begin
        result_valid <= 1'b0;
        if (reset) begin
            st <= IDLE; vptr <= '0; vote_ok <= '0; result <= '0; confidence <= '0; reject <= 1'b1;
            trained <= '0;
            t<=0;remainder<=0;ratio<=0;ratio_bit<=0;
            for(int c=0;c<NCLASS;c++) enrol_count[c]<=0;
        end
        else if (!enable) begin
            st<=IDLE;vote_ok<='0;vptr<='0;confidence<=0;reject<=1;
            result_valid<=feature_valid;
        end
        else case (st)
            IDLE: if(feature_valid && enrol) begin
                templ[enrol_class*NT+enrol_count[enrol_class]]<=feature;
                if(enrol_count[enrol_class]==NT-1) begin trained[enrol_class]<=1;enrol_count[enrol_class]<=0;end
                else enrol_count[enrol_class]<=enrol_count[enrol_class]+1;
                vote_ok<=0;vptr<=0;reject<=1;confidence<=0;result_valid<=1;
            end else if (feature_valid && (&trained)) begin
                f_q <= feature; t <= '0; d1 <= '1; d2 <= '1; best_class <= '0; st <= DIST;
            end else if (feature_valid) begin
                vote_ok <= '0;                                 // gate closed: forget the vote
                result_valid <= 1'b1; confidence <= '0; reject <= 1'b1;
            end
            DIST: begin
                if (sad < d1) begin
                    if (t_class != best_class) d2 <= d1;       // the old best becomes the runner-up of another class
                    d1 <= sad; best_class <= t_class;
                end else if (t_class != best_class && sad < d2) d2 <= sad;
                if (t == NTT-1) st <= DECIDE; else t <= t + 1'b1;
            end
            DECIDE: begin
                reject <= rej_c;
                if (!rej_c) begin
                    votes[vidx] <= best_class; vote_ok[vidx] <= 1'b1;
                    vptr <= (vptr == M-1) ? '0 : vptr + 1'b1;
                end
                confidence <= 0;
                remainder<={1'b0,d1};ratio<=0;ratio_bit<=0;
                st <= rej_c ? VOTE:CONFIDENCE;
            end
            CONFIDENCE: begin
                remainder<=doubled>=d2 ? doubled-d2:doubled;
                ratio<={ratio[6:0],doubled>=d2};
                if(ratio_bit==7) begin
                    confidence<=8'd255-{ratio[6:0],doubled>=d2};st<=VOTE;
                end else ratio_bit<=ratio_bit+1'b1;
            end
            VOTE: begin                                        // one cycle later: the tally includes this frame's vote
                result <= winner;
                result_valid <= 1'b1;
                st <= IDLE;
            end
            default: st <= IDLE;
        endcase
    end
endmodule
