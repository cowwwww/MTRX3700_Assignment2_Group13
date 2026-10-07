`timescale 1ns/1ps
// Catch swapped/stale ROM slots, wrong address order and non-synchronous reads.
module tb_image_store;
 logic analysis_clk=0,pixel_clk=0;
 always #5 analysis_clk=~analysis_clk;
 always #7 pixel_clk=~pixel_clk;
 logic [1:0] analysis_image=0,display_image=0;
 logic [16:0] analysis_address=0,display_address=0;
 wire [7:0] analysis_pixel,display_pixel;
 logic [7:0] expected0[0:76799],expected1[0:76799],expected2[0:76799];
 bit analysis_done=0,display_done=0;
 image_store dut(.*);
 function automatic logic [7:0] expected(input int slot,input int address);
  case(slot)
   1:return expected1[address];
   2:return expected2[address];
   default:return expected0[address];
  endcase
 endfunction
 initial begin
  $readmemh("assets/piano0.hex",expected0);
  $readmemh("assets/piano1.hex",expected1);
  $readmemh("assets/piano2.hex",expected2);
  fork
   begin
    for(int slot=0;slot<4;slot++) for(int address=0;address<76800;address++) begin
     @(negedge analysis_clk);analysis_image=2'(slot);analysis_address=17'(address);
     @(posedge analysis_clk);#1;
     if(analysis_pixel!==expected(slot,address)) $fatal(1,"analysis ROM slot=%0d address=%0d",slot,address);
    end
    analysis_done=1;
   end
   begin
    for(int slot=3;slot>=0;slot--) for(int address=76799;address>=0;address--) begin
     @(negedge pixel_clk);display_image=2'(slot);display_address=17'(address);
     @(posedge pixel_clk);#1;
     if(display_pixel!==expected(slot,address)) $fatal(1,"display ROM slot=%0d address=%0d",slot,address);
    end
    display_done=1;
   end
  join
  if(!analysis_done || !display_done) $fatal(1,"incomplete ROM sweep");
  $display("ALL TESTS PASSED: tb_image_store");$finish;
 end
 initial begin #5000000;$fatal(1,"watchdog");end
endmodule
