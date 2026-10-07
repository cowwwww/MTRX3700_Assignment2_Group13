`timescale 1ns/1ps
module tb_piano_detector;
 logic clk=0;always #5 clk=~clk;
 logic reset=1;logic [1:0] image_select=0;logic use_sobel=0;
 logic [7:0] high_threshold=96,low_threshold=32;
 wire [16:0] rom_addr;logic [7:0] rom_pixel;
 logic publish_busy=0;wire publish;
 wire [2559:0] profile;wire [143:0] boundaries;wire [4:0] boundary_count;
 wire edge_bank;wire [1:0] selected_image;wire [7:0] selected_high,selected_low;
 wire edge_write;wire [17:0] edge_address;wire [7:0] edge_value;
 logic [7:0] expected_profile[0:319],expected_edge[0:76799];
 bit seen[0:76799];
 logic [8:0] expected_keys[0:16];integer writes;
 logic [7:0] captured[0:76799];integer capture_file;
 piano_detector dut(.*);
 // Test the real image selection and clocked ROM.
 image_store rom(.analysis_clk(clk),.pixel_clk(clk),.analysis_image(selected_image),
  .display_image(2'd0),.analysis_address(rom_addr),.display_address(17'd0),
  .analysis_pixel(rom_pixel),.display_pixel());
 always @(negedge clk) if(!reset && edge_write) begin
  if(edge_address>=153600) $fatal(1,"edge address out of range");
  if(seen[edge_address%76800]) $fatal(1,"duplicate edge pixel %0d",edge_address%76800);
  seen[edge_address%76800]=1;
  if(edge_value!==expected_edge[edge_address%76800]) $fatal(1,"edge at %0d expected %0d got %0d",edge_address%76800,expected_edge[edge_address%76800],edge_value);
  writes++;
  captured[edge_address%76800]=edge_value;
 end
 initial begin
  for(int picture=0;picture<2;picture++) for(int mode=0;mode<2;mode++) begin
   reset=1;repeat(8) @(negedge clk);
   $readmemh($sformatf("assets/expected_%0d_%0d.hex",picture,mode),expected_profile);
   $readmemh($sformatf("assets/expected_%0d_%0d_edges.hex",picture,mode),expected_edge);
   $readmemh($sformatf("assets/expected_%0d_%0d_keys.hex",picture,mode),expected_keys);
   image_select=picture;use_sobel=mode;writes=0;reset=0;
   // Run twice without reset to catch column totals left uncleared.
   repeat(2) begin
    writes=0;
    for(int p=0;p<76800;p++) begin captured[p]=0;seen[p]=0;end
    wait(publish);#1;
    for(int x=0;x<320;x++) if(profile[x*8+:8]!==expected_profile[x]) $fatal(1,"profile column %0d expected %0d got %0d",x,expected_profile[x],profile[x*8+:8]);
    if(boundary_count!==expected_keys[0][4:0]) $fatal(1,"boundary count %0d expected %0d",boundary_count,expected_keys[0]);
    for(int k=0;k<boundary_count;k++) if(boundaries[k*9+:9]!==expected_keys[k+1]) $fatal(1,"boundary %0d",k);
    if(boundary_count<5) $fatal(1,"cannot play four keys");
    if(selected_image!=picture || selected_high!=96 || selected_low!=32) $fatal(1,"metadata mismatch");
    if(writes!=(mode ? 318*238 : 319*240)) $fatal(1,"incomplete edge map: %0d writes",writes);
    capture_file=$fopen($sformatf("build/rtl_edge_%0d_%0d.ppm",picture,mode),"w");
    if(capture_file==0) $fatal(1,"cannot write edge capture");
    $fwrite(capture_file,"P3\n320 240\n255\n");
    for(int p=0;p<76800;p++) $fwrite(capture_file,"%0d %0d %0d\n",captured[p],captured[p],captured[p]);
    $fclose(capture_file);
    @(negedge clk);publish_busy=1;repeat(12) @(negedge clk);publish_busy=0;
   end
  end
  $display("ALL TESTS PASSED: tb_piano_detector");$finish;
 end
 initial begin #30000000;$fatal(1,"watchdog");end
endmodule
