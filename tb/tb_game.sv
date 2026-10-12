`timescale 1ns/1ps
module tb_game;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,enable=1,decision_valid=0,reject=0;
 logic [7:0] confidence=255;logic [1:0] vowel=0;
 wire [6:0] score;wire [3:0] active,hit_window,hit_led;wire [3:0][3:0] countdown;
 game #(.BEAT_CLKS(20)) dut(.*);
 integer expected=0;
 task decision(input integer lane,input bit rejected);
  @(negedge clk);vowel=lane;reject=rejected;decision_valid=1;
  @(negedge clk);decision_valid=0;repeat(2) @(negedge clk);
 endtask
 always @(negedge clk) if(!reset && $countones(hit_window)>1) $fatal(1,"overlapping hit windows");
 initial begin
  repeat(3) @(negedge clk);reset=0;
  wait(active[0] && countdown[0]>0);decision(0,0);
  if(score!=0) $fatal(1,"early decision scored");
  wait(hit_window[0]);decision(1,0);decision(0,1);
  if(score!=0) $fatal(1,"wrong/rejected decision scored");
  decision(0,0);expected=1;if(score!=expected) $fatal(1,"correct decision not scored");
  decision(0,0);if(score!=expected) $fatal(1,"duplicate score");
  wait(hit_window[1]);wait(!hit_window[1]);if(score!=expected) $fatal(1,"miss scored");
  repeat(800) @(negedge clk);
  reset=1;@(negedge clk);if(score!=0) $fatal(1,"reset score");
  $display("ALL TESTS PASSED: tb_game");$finish;
 end
 initial begin #50000;$fatal(1,"watchdog");end
endmodule
