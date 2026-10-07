`timescale 1ns/1ps
module tb_cdc_mailbox;
 logic src_clk=0,dst_clk=0;
 always #7 src_clk=~src_clk;always #11 dst_clk=~dst_clk;
 logic src_reset=1,dst_reset=1,src_valid=0,dst_accept=0;
 logic [31:0] src_data=0;
 wire src_busy,dst_valid;wire [31:0] dst_data;
 cdc_mailbox #(.WIDTH(32)) dut(.*);
 initial begin
  #55;src_reset=0;dst_reset=0;
  for(int i=0;i<40;i++) begin
   wait(!src_busy);@(negedge src_clk);src_data=32'h12340000+i;src_valid=1;
   @(negedge src_clk);src_valid=0;src_data=32'hbadbad00;
   repeat(5) @(negedge dst_clk);
   if(dst_valid) $fatal(1,"update outside blanking");
   dst_accept=1;wait(dst_valid);#1;
   if(dst_data!=32'h12340000+i) $fatal(1,"torn CDC payload");
   @(negedge dst_clk);dst_accept=0;
   wait(!src_busy);
  end
  $display("ALL TESTS PASSED: tb_cdc_mailbox");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
