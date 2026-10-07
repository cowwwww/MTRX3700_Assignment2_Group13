`timescale 1ns/1ns
module low_pass_conv #(parameter W, W_FRAC) (
    input clk,

    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data
);

    // Lesson 4's low_pass_conv module version takes up too many DSP blocks.
    // Copy the solution from:
    // https://edstem.org/au/courses/37268/lessons/111809/edit/slides/820063

endmodule
