`timescale 1ns/1ns
/* Test 1: x[0] = 127, x[3] = -128, x[6] = 64 with width 16 and frac len 8.
 */
module rc_low_pass_tb1;

    localparam TCLK = 20; // 20ns

    localparam W = 16;
    localparam W_FRAC = 8;

    logic clk = 0;
    logic [W-1:0] x_data, y_data;
    logic x_valid, x_ready;
    logic y_valid, y_ready;

    rc_low_pass #(.W(W), .W_FRAC(W_FRAC), .ALPHA(16'b00000000_10000000)) DUT (.*);  // Alpha = 0.5 in 16-bit (8-bit frac) fixed point.

    always #(TCLK/2) clk = ~clk;

    localparam LEN = 64;
    // 64 x[n] values with impulse x[0] = 127, x[3] = -128, x[6] = 64:
    logic [W-1:0] audio_data [0:LEN-1] = '{16'h7F_00,16'h00_00,16'h00_00,16'h80_00,16'h00_00,16'h00_00,16'h40_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00,16'h00_00};
    // LCCDE y[n] = 0.5*x[n] + (1-0.5)*y[n-1] should produce the following 19 non-zero values:
    localparam OUT_LEN = 19;
    logic [W-1:0] expected [0:OUT_LEN-1] = '{16'h3f80,16'h1fc0,16'h0fe0,16'hc7f0,16'he3f8,16'hf1fc,16'h18fe,16'h0c7f,16'h063f,16'h031f,16'h018f,16'h00c7,16'h0063,16'h0031,16'h0018,16'h000c,16'h0006,16'h0003,16'h0001};

    logic start = 0;
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars();
        y_ready = 1'b0;
        #(TCLK*5);
        y_ready = 1'b1;
        start = 1'b1;
        @(posedge x_valid);
        @(negedge x_valid);
        #(TCLK*5);
        $finish();
    end

    // Input Driver:
    integer i = 0;
    always_ff @(posedge clk) begin
        if (start) begin
            x_data <= audio_data[i];
            i <= i < LEN ? i + 1 : LEN;
            x_valid <= i < LEN ? 1'b1 : 1'b0;
        end
    end

    // Output Check:
    always_ff @(posedge clk) begin
        if (x_ready != y_ready) $error("x_ready != y_ready");
        if (y_valid != x_valid) $error("y_valid != x_valid!");
        if (i > 0 && i < OUT_LEN+1) begin
            if (y_data != expected[i-1]) $error("Time %d : Expected value %h but got %h.",$time,expected[i-1],y_data);
        end
    end
endmodule

