module fft_mag_sq #(
    parameter W = 16
) (
    input                clk,
    input                reset,
    input                fft_valid,
    input        [W-1:0] fft_imag,
    input        [W-1:0] fft_real,
    output logic [W*2:0] mag_sq,
    output logic         mag_valid
);

    logic signed [W*2-1:0] multiply_stage_real, multiply_stage_imag;
    logic signed [W*2:0]   add_stage;
    logic [1:0] valid_shift;
    always_ff @(posedge clk) begin
       //TODO Your code here!
       // We want to implement the 2 pipeline stages, similar to task 1.1.
       // When multiplying, make sure to use the signed function, e.g: signed'(fft_real)*signed'(fft_real);
       // Remember to use reset.
       if (reset) begin
            multiply_stage_real <= '0;
            multiply_stage_imag <= '0;
            add_stage           <= '0;
            valid_shift         <= '0;
        end
        else begin
            // Pipeline stage 1: calculate real² and imaginary²
            multiply_stage_real <= signed'(fft_real) * signed'(fft_real);
            multiply_stage_imag <= signed'(fft_imag) * signed'(fft_imag);

            // Pipeline stage 2: add the two squared values
            add_stage <= {1'b0, multiply_stage_real}
                       + {1'b0, multiply_stage_imag};

            // Delay fft_valid by two clock cycles
            valid_shift <= {valid_shift[0], fft_valid};
        end
    end

    assign mag_sq    = add_stage;
    assign mag_valid =  valid_shift[1];

    //TODO set to `1` when mag_sq valid **this should be 2 cycles after valid input!**
    // Hint: you can use a shift register to implement valid.

endmodule
