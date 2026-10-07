module fft_input_buffer #(
    parameter W = 16,
    parameter NSamples = 1024
) (
     input                clk,
     input                reset,
     input                audio_clk,
     
     input  logic         audio_input_valid,
     output logic         audio_input_ready,
     input  logic [W-1:0]   audio_input_data,

     output logic [W-1:0] fft_input,
     output logic         fft_input_valid
);

    // Copy & Paste your solution to Lesson 4 fft_input_buffer.sv here!

endmodule
