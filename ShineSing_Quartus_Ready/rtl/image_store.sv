module image_store #(parameter W=320,H=240)(
 input logic analysis_clk, pixel_clk,
 input logic [1:0] analysis_image, display_image,
 input logic [$clog2(W*H)-1:0] analysis_address, display_address,
 output logic [7:0] analysis_pixel, display_pixel
);
 // Hardware consumes the separate MIFs, so the tutor image is a direct file swap.
 // Simulation uses equivalent readmemh files (portable across ModelSim/Verilator).
 (* ram_init_file="assets/piano0.mif" *) logic [7:0] image0[0:W*H-1];
 (* ram_init_file="assets/piano1.mif" *) logic [7:0] image1[0:W*H-1];
 (* ram_init_file="assets/piano2.mif" *) logic [7:0] image2[0:W*H-1];
 logic [7:0] a0,a1,a2,d0,d1,d2;
`ifndef SYNTHESIS
 initial begin
  $readmemh("assets/piano0.hex",image0);
  $readmemh("assets/piano1.hex",image1);
  $readmemh("assets/piano2.hex",image2);
 end
`endif
 always_ff @(posedge analysis_clk) begin a0<=image0[analysis_address];a1<=image1[analysis_address];a2<=image2[analysis_address];end
 always_ff @(posedge pixel_clk) begin d0<=image0[display_address];d1<=image1[display_address];d2<=image2[display_address];end
 always_comb begin
  analysis_pixel=analysis_image==1 ? a1 : analysis_image==2 ? a2 : a0;
  display_pixel=display_image==1 ? d1 : display_image==2 ? d2 : d0;
 end
endmodule
