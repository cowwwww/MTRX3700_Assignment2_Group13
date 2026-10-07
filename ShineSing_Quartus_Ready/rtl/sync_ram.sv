// Read and write RAM on one clock. Reads take one clock and return old data.
// Use M10K memory so Quartus 18.1 does not turn large buffers into registers.
// The simulation model uses the same read and write rules.
module sync_ram #(parameter WIDTH=16,DEPTH=2048,AW=$clog2(DEPTH))(
 input wire clk,we,
 input wire [AW-1:0] waddr,raddr,
 input wire [WIDTH-1:0] wdata,
 output wire [WIDTH-1:0] rdata
);
`ifdef SYNTHESIS
 altsyncram #(.operation_mode("DUAL_PORT"),.width_a(WIDTH),.widthad_a(AW),.numwords_a(DEPTH),
  .width_b(WIDTH),.widthad_b(AW),.numwords_b(DEPTH),.width_byteena_a(1),
  .address_reg_b("CLOCK0"),.outdata_reg_b("UNREGISTERED"),
  .read_during_write_mode_mixed_ports("OLD_DATA"),.ram_block_type("M10K"),
  .intended_device_family("Cyclone V"),.lpm_type("altsyncram")) ram(
  .clock0(clk),.clocken0(1'b1),
  .aclr0(1'b0),.aclr1(1'b0),.address_a(waddr),.address_b(raddr),.data_a(wdata),.wren_a(we),
  .wren_b(1'b0),.data_b({WIDTH{1'b0}}),.rden_a(1'b1),.rden_b(1'b1),.byteena_a(1'b1),.byteena_b(1'b1),
  .addressstall_a(1'b0),.addressstall_b(1'b0),.q_b(rdata),.q_a(),.eccstatus());
`else
 logic [WIDTH-1:0] mem[0:DEPTH-1];
 logic [WIDTH-1:0] q;
 always_ff @(posedge clk) begin
  if(we) mem[waddr]<=wdata;
  q<=mem[raddr];
 end
 assign rdata=q;
`endif
endmodule
