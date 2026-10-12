`timescale 1ns/1ps
module tb_classifier;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,enable=1,feature_valid=0,enrol=0;
 logic [7:0][15:0] feature=0;logic [1:0] enrol_class=0;
 wire [3:0] trained;wire [1:0] result;wire [7:0] confidence;wire reject,result_valid;
 classifier #(.M(3),.DMAX(10000)) dut(.*);
 task send(input integer vowel,input bit training);
  @(negedge clk);feature=0;feature[vowel]=20000;enrol=training;enrol_class=vowel;feature_valid=1;
  @(negedge clk);feature_valid=0;wait(result_valid);#1;
  @(negedge clk);
 endtask
 initial begin
  repeat(3) @(negedge clk);reset=0;
  send(0,0);if(!reject) $fatal(1,"accepted untrained templates");
  for(int c=0;c<4;c++) repeat(4) send(c,1);
  if(trained!=15) $fatal(1,"enrolment failed");
  for(int c=0;c<4;c++) begin
   repeat(3) send(c,0);
   if(reject || result!=c || confidence!=255) $fatal(1,"classification %0d got %0d reject %0d confidence %0d",c,result,reject,confidence);
  end
  @(negedge clk);feature='1;feature_valid=1;
  @(negedge clk);feature_valid=0;wait(result_valid);#1;
  if(!reject || confidence!=0) $fatal(1,"far feature accepted");
  @(negedge clk);enable=0;repeat(3) @(negedge clk);
  if(!reject || confidence!=0) $fatal(1,"silence not rejected immediately");
  enable=1;send(0,0);if(result!=0) $fatal(1,"stale vote after silence");
  $display("ALL TESTS PASSED: tb_classifier");$finish;
 end
 initial begin #50000;$fatal(1,"watchdog");end
endmodule
