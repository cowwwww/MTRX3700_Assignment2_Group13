// Adapted from home (1).zip: added reset, a busy check and output scaling.
`timescale 1ns/1ns
/*
 * 41-tap FIR filter before downsampling, based on Lesson 4.
 * Use one multiplier for all taps to save DSP resources.
 *
 * With the default widths, x_data holds a signed 16-bit sample followed
 * by 16 zero bits. Multiply the sample by each Q16 filter weight, then
 * add the products. OUTPUT_SHIFT scales the result before clipping it
 * and storing it in y_data.
 *
 * Each result takes 43 filter clocks. On the board, 48 kHz samples arrive
 * about 384 cycles apart on the 18.432 MHz filter clock. This is also
 * 64 cycles of the separate 3.072 MHz audio bit clock.
 * Only accept a sample when x_ready is high; ignore it while busy.
 */
module low_pass_conv #(parameter W = 32, W_FRAC = 16, OUTPUT_SHIFT = 2) (
    input clk,
    input reset,

    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data
);
    logic running = 1'b0, prod_valid = 1'b0, done = 1'b0;
    assign x_ready = y_ready && !running && !reset;

    localparam int N  = 41;
    localparam int XW = W - W_FRAC;          // integer bits of the sample (16)
    localparam int CW = 18;                  // coefficient bits kept (signed; the taps fit in 17)
    // Lesson 4 filter weights: signed 32-bit values with 16 fraction bits.
    localparam logic [W-1:0] h [0:N-1] = '{32'h00000000, 32'h00000014, 32'h0000003f, 32'h00000050, 32'h00000000, 32'hffffff0b, 32'hfffffd56, 32'hfffffb08, 32'hfffff8a1, 32'hfffff6ee, 32'hfffff6f3, 32'hfffff9b5, 32'h00000000, 32'h00000a2d, 32'h000017f4, 32'h00002860, 32'h000039e3, 32'h00004a8b, 32'h0000584b, 32'h0000615d, 32'h00006488, 32'h0000615d, 32'h0000584b, 32'h00004a8b, 32'h000039e3, 32'h00002860, 32'h000017f4, 32'h00000a2d, 32'h00000000, 32'hfffff9b5, 32'hfffff6f3, 32'hfffff6ee, 32'hfffff8a1, 32'hfffffb08, 32'hfffffd56, 32'hffffff0b, 32'h00000000, 32'h00000050, 32'h0000003f, 32'h00000014, 32'h00000000};

    // Store the last N samples, keeping only their integer bits.
    logic signed [XW-1:0] shift_reg [0:N-1];
    always_ff @(posedge clk) if(reset) begin
        for(int i=0;i<N;i++) shift_reg[i] <= '0;
    end else if (x_valid & x_ready) begin
        shift_reg[0] <= signed'(x_data[W-1 -: XW]);
        for (int i = 1; i < N; i++) shift_reg[i] <= shift_reg[i-1];
    end

    // Multiply one tap per clock and add its product to the running sum.
    logic [$clog2(N)-1:0] tap = '0, tap_q = '0;
    logic signed [XW+CW-1:0] prod;
    logic signed [XW+CW+$clog2(N)-1:0] acc;
    always_ff @(posedge clk) begin
        if(reset) begin
            running<=0;tap<=0;tap_q<=0;prod_valid<=0;done<=0;prod<=0;acc<=0;
        end else begin
        if (x_valid & x_ready) begin running <= 1'b1; tap <= '0; end          // Start when a new sample is accepted.
`ifndef SYNTHESIS
        if (x_valid & x_ready & running) $error("low_pass_conv: a sample arrived before the last one was filtered (need %0d clocks between samples)", N + 2);
`endif
        else if (running) begin
            if (tap == N-1) running <= 1'b0; else tap <= tap + 1'b1;
        end
        prod       <= shift_reg[tap] * signed'(h[tap][CW-1:0]);              // Reuse this multiplier for every tap.
        prod_valid <= running;
        tap_q      <= tap;
        if (prod_valid) acc <= (tap_q == 0) ? prod : acc + prod;
        done       <= prod_valid && (tap_q == N-1);
        end
    end

    // Store the filtered result in the W-bit format used by the downsampler.
    always_ff @(posedge clk) begin
        if(reset) begin y_valid<=0;y_data<=0;end
        else begin
            if (y_ready) y_valid <= 1'b0;
            if (done) begin
                // Scale before narrowing so loud sounds do not wrap around.
                if((acc >>> OUTPUT_SHIFT) > 40'sd2147483647) y_data<=32'h7fffffff;
                else if((acc >>> OUTPUT_SHIFT) < -40'sd2147483648) y_data<=32'h80000000;
                else y_data <= W'(acc >>> OUTPUT_SHIFT);
                y_valid <= 1'b1;
            end
        end
    end
endmodule
