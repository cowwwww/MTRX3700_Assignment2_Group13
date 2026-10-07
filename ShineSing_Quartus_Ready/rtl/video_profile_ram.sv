// Store profile and local-average columns in two RAM banks, one per frame.
// Never write the displayed bank; swap banks through the frame mailbox.
module video_profile_ram #(parameter W=320,AW=$clog2(W))(
 input wire write_clk,write_enable,write_bank,
 input wire [AW-1:0] write_column,
 input wire [15:0] write_data,
 input wire read_clk,read_bank,
 input wire [AW-1:0] read_column,
 output wire [15:0] read_data
);
 localparam DEPTH=2*(1<<AW);
`ifdef SYNTHESIS
 altsyncram #(.operation_mode("DUAL_PORT"),
  .width_a(16),.widthad_a(AW+1),.numwords_a(DEPTH),
  .width_b(16),.widthad_b(AW+1),.numwords_b(DEPTH),.width_byteena_a(1),
  .address_reg_b("CLOCK1"),.outdata_reg_b("UNREGISTERED"),
  .read_during_write_mode_mixed_ports("DONT_CARE"),.ram_block_type("M10K"),
  .intended_device_family("Cyclone V"),.lpm_type("altsyncram")) ram(
  .clock0(write_clk),.clock1(read_clk),.clocken0(1'b1),.clocken1(1'b1),
  .aclr0(1'b0),.aclr1(1'b0),.address_a({write_bank,write_column}),
  .address_b({read_bank,read_column}),.data_a(write_data),.wren_a(write_enable),
  .wren_b(1'b0),.data_b(16'd0),.rden_a(1'b1),.rden_b(1'b1),
  .byteena_a(1'b1),.byteena_b(1'b1),.addressstall_a(1'b0),.addressstall_b(1'b0),
  .q_b(read_data),.q_a(),.eccstatus());
`else
 logic [15:0] memory[0:DEPTH-1];
 logic [15:0] q;
 always_ff @(posedge write_clk) if(write_enable) memory[{write_bank,write_column}]<=write_data;
 always_ff @(posedge read_clk) q<=memory[{read_bank,read_column}];
 assign read_data=q;
`endif
endmodule
