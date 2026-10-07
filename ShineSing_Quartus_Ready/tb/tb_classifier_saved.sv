`timescale 1ns/1ps
// Use the supplied synthetic course templates to test saved-ROM loading.
module tb_classifier_saved;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,enable=1,feature_valid=0,enrol=0;
 logic [7:0][15:0] feature=0;
 logic [1:0] enrol_class=0;
 wire [3:0] trained;wire [1:0] result;
 wire [7:0] confidence;wire reject,result_valid;
 `include "course_sources/classifier/templates_test.svh"
 classifier #(.D(8),.NT(4),.M(3),.PRETRAINED(1),.SAVED_TEMPLATES(TEMPLATES),.DMAX(500)) dut(.*);
 task send(input int c);
  @(negedge clk);feature=TEMPLATES[c*4];feature_valid=1;
  @(negedge clk);feature_valid=0;
  wait(result_valid);#1;
  if(reject || confidence!=255) $fatal(1,"saved match rejected");
  @(negedge clk);
 endtask
 initial begin
  repeat(3) @(negedge clk);reset=0;
  if(trained!=15) $fatal(1,"saved classes not ready at startup");
  for(int c=0;c<4;c++) begin
   repeat(3) send(c);
   if(result!=c) $fatal(1,"wrong saved class");
  end
  // The enrol button must not overwrite the saved examples.
  enrol=1;enrol_class=0;repeat(4) send(3);enrol=0;
  reset=1;repeat(3) @(negedge clk);reset=0;
  send(0);if(result!=0 || trained!=15) $fatal(1,"reset lost saved examples");
  @(negedge clk);enable=0;@(negedge clk);
  if(!reject || confidence!=0) $fatal(1,"silence accepted");
  enable=1;send(2);if(result!=2) $fatal(1,"old votes survived silence");
  $display("ALL TESTS PASSED: tb_classifier_saved");$finish;
 end
 initial begin #50000;$fatal(1,"watchdog");end
endmodule
