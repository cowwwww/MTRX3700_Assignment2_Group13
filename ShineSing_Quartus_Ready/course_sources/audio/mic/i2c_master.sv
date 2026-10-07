module i2c_master (
    input  clk,      // 20 kHz input clock

    output i2c_scl,  // I2C clock
    inout  i2c_sda,  // I2C DATA

    input  [6:0] slav_addr,
    input  read_not_write,
    input  [7:0] reg_addr,

    input  [7:0] write_data,
    input  write_valid,
    output logic write_ready,

    output logic [7:0] read_data,
    output logic read_valid,
    input  read_ready,

    output logic error
);

    // Copy & Paste your solution to Lesson 3 i2c_master.sv here!

endmodule
