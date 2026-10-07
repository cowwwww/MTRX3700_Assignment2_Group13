`timescale 1ns/1ps
module tb_audio_features;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,mag_valid=0;logic [32:0] mag=0;
 wire [7:0][15:0] feature;wire feature_valid;wire [8:0] peak_bin;
 audio_features dut(.*);
 localparam int EDGE[0:8]='{8,32,64,100,140,200,280,380,512};
 longint unsigned expected[0:7],total,power;
 integer bin;
 task frame(input integer scale);
  total=0;for(int j=0;j<8;j++) expected[j]=0;
  for(int i=0;i<1024;i++) begin
   bin=0;for(int j=0;j<10;j++) bin=bin | (((i>>j)&1)<<(9-j));
   power=(bin==77 ? 9000 : (bin+1))*scale;
   for(int b=0;b<8;b++) if(bin>=EDGE[b] && bin<EDGE[b+1]) begin expected[b]+=power;total+=power;end
   @(negedge clk);mag_valid=1;mag=power;
   // Deliberate bubbles must not reset the FFT index or drop a bin.
   if(i%19==0) begin @(negedge clk);mag_valid=0;end
  end
  @(negedge clk);mag_valid=0;
  wait(feature_valid);#1;
  if(peak_bin!=77) $fatal(1,"peak expected 77 got %0d",peak_bin);
  for(int b=0;b<8;b++) if(feature[b] != ((expected[b]<<16)/total)) $fatal(1,"band %0d expected %0d got %0d",b,(expected[b]<<16)/total,feature[b]);
  @(negedge clk);
 endtask
 initial begin
  repeat(3) @(negedge clk);reset=0;frame(1);frame(4);
  // Silence clears every accumulator and never divides by zero.
  for(int i=0;i<1024;i++) begin @(negedge clk);mag_valid=1;mag=0;end
  @(negedge clk);mag_valid=0;wait(feature_valid);#1;
  if(feature!==0 || peak_bin!==0) $fatal(1,"silence did not clear features");
  $display("ALL TESTS PASSED: tb_audio_features");$finish;
 end
 initial begin #200000;$fatal(1,"watchdog");end
endmodule
