`timescale 1ns/1ps
module tb_board_controls;
 logic clk=0;always #5 clk=~clk;
 logic reset=1;logic [9:0] sw=0;logic [3:0] key=15;
 wire [9:0] switches;wire enrol;wire [7:0] high_threshold,low_threshold;
 board_controls #(.DEBOUNCE(4)) dut(.*);
 task settle;repeat(12) @(negedge clk);endtask
 task press(input integer k);key[k]=0;settle();key[k]=1;settle();endtask
 initial begin
  settle();reset=0;settle();
  if(switches!=0 || enrol || high_threshold!=96 || low_threshold!=32) $fatal(1,"reset controls");
  key[1]=0;@(negedge clk);key[1]=1;settle();if(high_threshold!=96) $fatal(1,"bounce accepted");
  press(1);if(high_threshold!=104) $fatal(1,"high increment");
  press(2);if(high_threshold!=96) $fatal(1,"high decrement");
  sw=10'b0011000001;settle();press(1);if(low_threshold!=40) $fatal(1,"low increment");
  press(2);if(low_threshold!=32) $fatal(1,"low decrement");
  key[3]=0;settle();if(!enrol || switches!=sw) $fatal(1,"enrol switches");
  key[3]=1;settle();if(enrol) $fatal(1,"enrol release");
  $display("ALL TESTS PASSED: tb_board_controls");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
