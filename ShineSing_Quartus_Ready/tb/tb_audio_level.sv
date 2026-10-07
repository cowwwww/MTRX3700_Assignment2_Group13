`timescale 1ns/1ps
module tb_audio_level;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,sample_valid=0;logic signed [15:0] sample=0;
 wire voice;wire [6:0] db;wire [9:0] bar;wire [15:0] level,noise;
 audio_level #(.BLOCK(16),.CAL_BLOCKS(4),.MARGIN(64)) dut(.*);
 task block(input integer amplitude,input integer expected_db);
  for(int i=0;i<16;i++) begin @(negedge clk);sample_valid=1;sample=i%2 ? -amplitude:amplitude;end
  @(negedge clk);sample_valid=0;#1;
  if(level!=amplitude || db!=expected_db) $fatal(1,"level/dB %0d %0d expected %0d %0d",level,db,amplitude,expected_db);
  for(int i=0;i<10;i++) if(bar[i]!=(amplitude >= (32<<i))) $fatal(1,"LED level bar");
 endtask
 initial begin
  repeat(3) @(negedge clk);reset=0;
  repeat(4) block(10,20);
  if(voice) $fatal(1,"gate open during calibration");
  block(1000,60);if(!voice) $fatal(1,"gate did not open");
  block(2000,66);if(!voice) $fatal(1,"gate closed on voice");
  block(0,0);if(voice) $fatal(1,"gate never clears");
  block(32768,90);
  $display("ALL TESTS PASSED: tb_audio_level");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
