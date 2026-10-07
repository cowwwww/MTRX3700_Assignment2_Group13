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

	// Copy & Paste your solution to Lesson 4 fft_mag_sq.sv here!

endmodule
