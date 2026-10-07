`timescale 1ns/1ps
module tb_codec_config;
 logic clk=0;always #5 clk=~clk;
 logic reset=1;
 wire scl,configured;tri1 sda;logic ack_low=0;
 assign sda=ack_low ? 1'b0:1'bz;
 codec_config #(.HALF_PERIOD(4)) dut(.*);
 localparam logic [15:0] CMD[0:10]='{16'h1e00,16'h00ff,16'h02ff,16'h04fd,16'h06fd,16'h083d,16'h0a00,16'h0c00,16'h0e41,16'h1002,16'h1201};
 integer bits=0,transaction=0;logic [23:0] packet=0;
 logic started=0;
 // Decode the bus separately and send ACK on falling SCL after each byte.
 always @(negedge sda) if(scl && !reset && !ack_low) begin started=1;bits=0;packet=0;end
 always @(negedge scl) if(started) ack_low=(bits%9==8);
 always @(posedge scl) if(started) begin
  if(bits<27) begin
   if(bits%9!=8) packet={packet[22:0],sda};
   bits++;
  end
 end
 always @(posedge sda) if(scl && started && !reset && bits==27) begin
  if(packet!=={8'h34,CMD[transaction]}) $fatal(1,"codec packet %0d got %h expected %h",transaction,packet,{8'h34,CMD[transaction]});
  transaction++;started=0;ack_low=0;
 end
 initial begin
  repeat(4) @(negedge clk);reset=0;wait(configured);#20;
  if(transaction!=11 || scl!==1 || sda!==1) $fatal(1,"codec did not finish %0d",transaction);
  $display("ALL TESTS PASSED: tb_codec_config");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
