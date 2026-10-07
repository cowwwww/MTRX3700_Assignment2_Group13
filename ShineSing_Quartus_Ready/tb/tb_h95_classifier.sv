`timescale 1ns/1ps
// Check real held-out H95 frames against independent Python distance results.
module tb_h95_classifier;
 `include "rtl/templates.svh"
 `include "assets/h95/test_dimensions.svh"
 logic clk=0;always #5 clk=~clk;
 logic reset=1,enable=0,feature_valid=0,enrol=0;
 logic [23:0][15:0] feature=0;logic [1:0] enrol_class=0;
 wire [3:0] trained;wire [1:0] result;wire [7:0] confidence;wire reject,result_valid;
 classifier #(.D(24),.M(3),.DMAX(65000),.PRETRAINED(1),.SAVED_CLASSES({4{TEMPLATES_READY}}),.SAVED_TEMPLATES(TEMPLATES)) dut(.*);
 logic [383:0] recorded[0:H95_TEST_FRAMES-1];logic [10:0] expected[0:H95_TEST_FRAMES-1];
 initial begin
  $readmemh("assets/h95/heldout_features.hex",recorded);
  $readmemh("assets/h95/heldout_expected.hex",expected);
  repeat(3) @(negedge clk);reset=0;
  if(trained!=15) $fatal(1,"H95 templates unavailable at startup");
  for(int i=0;i<H95_TEST_FRAMES;i++) begin
   enable=0;repeat(2) @(negedge clk);
   enable=1;feature=recorded[i];feature_valid=1;
   @(negedge clk);feature_valid=0;wait(result_valid);#1;
   if(reject!==expected[i][8] || confidence!==expected[i][7:0])
    $fatal(1,"H95 reject/confidence mismatch at frame %0d",i);
   if(!reject && result!==expected[i][10:9]) $fatal(1,"H95 class mismatch at frame %0d",i);
   @(negedge clk);
  end
  reset=1;repeat(3) @(negedge clk);reset=0;
  if(trained!=15) $fatal(1,"reset lost H95 templates");
  for(int c=0;c<4;c++) begin
   enable=0;repeat(2) @(negedge clk);enable=1;enrol=1;
   feature=TEMPLATES[c*4];feature_valid=1;
   @(negedge clk);feature_valid=0;wait(result_valid);#1;
   if(reject || result!=c || confidence!=255) $fatal(1,"saved template overwritten or wrong after reset");
   @(negedge clk);
  end
  $display("ALL TESTS PASSED: tb_h95_classifier");$finish;
 end
 initial begin #2000000;$fatal(1,"watchdog");end
endmodule
