`timescale 1ns/1ps
module tb_sync_ram;
 logic clk=0;always #5 clk=~clk;
 logic we=0;logic [2:0] waddr=0,raddr=0;logic [15:0] wdata=0;
 wire [15:0] rdata;
 sync_ram #(.WIDTH(16),.DEPTH(8),.AW(3)) dut(.*);
 logic [15:0] expected[0:7],old_value;
 initial begin
  for(int i=0;i<8;i++) begin
   @(negedge clk);we=1;waddr=i;wdata=i*7;
   @(posedge clk);#1;expected[i]=wdata;
  end
  for(int n=0;n<128;n++) begin
   @(negedge clk);we=n%3!=0;waddr=n%8;raddr=n%2 ? n%8:(n+3)%8;wdata=n*13;
   old_value=expected[raddr];
   @(posedge clk);#1;
   if(rdata!==old_value) $fatal(1,"RAM old-data mismatch got %h expected %h",rdata,old_value);
   if(we) expected[waddr]=wdata;
  end
  $display("ALL TESTS PASSED: tb_sync_ram");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
