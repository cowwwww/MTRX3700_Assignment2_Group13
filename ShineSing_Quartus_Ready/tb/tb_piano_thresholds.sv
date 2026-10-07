`timescale 1ns/1ps
// Directed checks: MIN_GAP merging, high/low thresholds, trailing run, blank image.
module tb_piano_thresholds;
 localparam W=64,H=8;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,blank=0,publish_busy=0;
 logic [7:0] high_threshold=96,low_threshold=32;
 wire [8:0] rom_addr;logic [7:0] rom_pixel;
 wire publish,edge_bank,edge_write;
 wire [511:0] profile;wire [95:0] boundaries;wire [4:0] boundary_count;
 wire [1:0] selected_image;wire [7:0] selected_high,selected_low,edge_value;
 wire [9:0] edge_address;
 piano_detector #(.W(W),.H(H),.Y0(0),.Y1(7),.MIN_GAP(8)) dut(
  .clk,.reset,.image_select(2'd0),.use_sobel(1'b0),.high_threshold,.low_threshold,
  .rom_addr,.rom_pixel,.publish_busy,.publish,.profile,.boundaries,.boundary_count,
  .edge_bank,.selected_image,.selected_high,.selected_low,.edge_write,.edge_address,.edge_value);
 always @(posedge clk) begin
  if(blank) rom_pixel<=0;
  else if(rom_addr%W<10) rom_pixel<=0;
  else if(rom_addr%W<14) rom_pixel<=120;
  else if(rom_addr%W<30) rom_pixel<=255;
  else if(rom_addr%W<40) rom_pixel<=0;
  else if(rom_addr%W<43) rom_pixel<=60;
  else if(rom_addr%W<60) rom_pixel<=0;
  // The final high run reaches column 63 and must be flushed.
  else rom_pixel<=8'((rom_addr%W-59)*60);
 end
 task check(input int count,input int a,input int b);
  wait(publish);#1;
  if(boundary_count!==5'(count)) $fatal(1,"threshold count: got %0d want %0d",boundary_count,count);
  if(count>0 && boundaries[0+:6]!==6'(a)) $fatal(1,"first boundary: got %0d want %0d",boundaries[0+:6],a);
  if(count>1 && boundaries[6+:6]!==6'(b)) $fatal(1,"second boundary");
 endtask
 task next_frame;
  @(negedge clk);publish_busy=1;
  repeat(4) @(negedge clk);publish_busy=0;
 endtask
 initial begin
  repeat(5) @(negedge clk);reset=0;
  // Peaks 10 (120) and 14 (135) merge to 14; 30 (255) survives.
  // 40/43 and the final plateau (60 each) have no high seed.
  check(2,14,30);
  high_threshold=200;next_frame();check(1,30,0);
  // Lower high threshold admits the weak pairs and trailing plateau.
  high_threshold=50;next_frame();
  wait(publish);#1;
  if(boundary_count!==5'd4 || boundaries[0+:6]!==6'd14 ||
     boundaries[6+:6]!==6'd30 || boundaries[12+:6]!==6'd40 ||
     boundaries[18+:6]!==6'd60) $fatal(1,"weak/trailing regions or spacing");
  low_threshold=150;next_frame();check(1,30,0);
  blank=1;next_frame();check(0,0,0);
  if(profile!==512'd0) $fatal(1,"blank frame retained previous profile");
  $display("ALL TESTS PASSED: tb_piano_thresholds");$finish;
 end
 initial begin #200000;$fatal(1,"watchdog");end
endmodule
