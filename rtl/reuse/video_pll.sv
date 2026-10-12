`timescale 1ns/1ps
/*
 * Generate the 25 MHz pixel clock from the board's 50 MHz clock.
 * Use Intel's altera_pll IP, as in the course video project.
 * The VGA controller uses this clock for its 640x480 output.
 *
 * For Verilator and ModelSim, use a simple 25 MHz clock generator
 * instead of the Intel PLL. This model always reports the PLL as locked.
 */
module video_pll (
    input  wire refclk,     // 50 MHz
    input  wire rst,
    output wire outclk_0,   // 25 MHz
    output wire locked
);
`ifdef VERILATOR
    `define VIDEO_PLL_SIM_STANDIN
`elsif MODEL_TECH
    `define VIDEO_PLL_SIM_STANDIN     // ModelSim predefines MODEL_TECH
`endif
`ifdef VIDEO_PLL_SIM_STANDIN
    logic clk_sim;
    initial clk_sim = 1'b0;
    always #(20ns) clk_sim = ~clk_sim;   // 25 MHz
    assign outclk_0 = clk_sim;
    assign locked   = 1'b1;
`else
    altera_pll #(
        .fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"),
        .operation_mode("normal"),
        .number_of_clocks(1),
        .output_clock_frequency0("25.000000 MHz"),
        .phase_shift0("0 ps"),
        .duty_cycle0(50),
        .pll_type("General"),
        .pll_subtype("General")
    ) altera_pll_i (
        .rst      (rst),
        .outclk   ({outclk_0}),
        .locked   (locked),
        .fboutclk ( ),
        .fbclk    (1'b0),
        .refclk   (refclk)
    );
`endif
endmodule
