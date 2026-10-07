`timescale 1ps/1ps
module mic_load #(parameter N=16) (
	input bclk, // Assume a 18.432 MHz clock
    input adclrc,
	input adcdat,

    output logic valid,
    output logic [N-1:0] sample_data
);

    // Copy & Paste your solution to Lesson 3 mic_load.sv here!

endmodule

