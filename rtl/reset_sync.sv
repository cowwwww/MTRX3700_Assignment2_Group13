module reset_sync(input logic clk, arst, output logic reset);
 (* async_reg="true" *) logic [1:0] pipe;
 always_ff @(posedge clk or posedge arst)
  if(arst) pipe<=2'b11; else pipe<={pipe[0],1'b0};
 assign reset=pipe[1];
endmodule
