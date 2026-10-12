`timescale 1ns/1ps
module tb_mic_load;
 logic bclk=0;always #10 bclk=~bclk;
 logic adclrc=0,adcdat=0;wire valid;wire [15:0] sample_data;
 mic_load dut(.*);
 integer received=0;logic [15:0] expected;
 always @(negedge bclk) if(valid) begin
  if(sample_data!==expected) $fatal(1,"LJ sample expected %h got %h",expected,sample_data);
  received++;
 end
 initial begin
  repeat(64) @(negedge bclk);
  for(int n=0;n<10;n++) begin
   expected=16'(16'h8123+n*257);
   for(int i=0;i<64;i++) begin
    @(negedge bclk);#1;adclrc=i<32;adcdat=i<16 ? expected[15-i]:0;
   end
  end
  repeat(4) @(negedge bclk);if(received!=10) $fatal(1,"missing samples");
  $display("ALL TESTS PASSED: tb_mic_load");$finish;
 end
 initial begin #30000;$fatal(1,"watchdog");end
endmodule
