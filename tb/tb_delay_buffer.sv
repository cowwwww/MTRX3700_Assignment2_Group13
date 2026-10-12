`timescale 1ns/1ps
module tb_delay_buffer;
 logic clock=0;always #5 clock=~clock;
 logic [15:0] di_re=0,di_im=0;
 wire [15:0] r1,i1,r2,i2,r32,i32;
 DelayBuffer #(.DEPTH(1)) d1(.clock,.di_re,.di_im,.do_re(r1),.do_im(i1));
 DelayBuffer #(.DEPTH(2)) d2(.clock,.di_re,.di_im,.do_re(r2),.do_im(i2));
 DelayBuffer #(.DEPTH(32)) d32(.clock,.di_re,.di_im,.do_re(r32),.do_im(i32));
 logic [15:0] re[0:999],im[0:999];
 initial begin
  for(int n=0;n<1000;n++) begin
   @(negedge clock);di_re=16'(n*197+61);di_im=~di_re;re[n]=di_re;im[n]=di_im;
   @(posedge clock);#1;
   if(r1!==re[n] || i1!==im[n]) $fatal(1,"depth1");
   if(n>=1 && (r2!==re[n-1] || i2!==im[n-1])) $fatal(1,"depth2");
   if(n>=31 && (r32!==re[n-31] || i32!==im[n-31])) $fatal(1,"depth32");
  end
  $display("ALL TESTS PASSED: tb_delay_buffer");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
