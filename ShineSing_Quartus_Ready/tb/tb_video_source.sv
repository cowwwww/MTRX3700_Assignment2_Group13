`timescale 1ns/1ps
module tb_video_source;
 localparam W=40,H=32,NMAX=16;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,ready=0;logic [1:0] view=1;
 logic [7:0] grey=0,edge_pixel=0;
 wire [10:0] address;
 logic [319:0] profile=0;logic [95:0] boundaries=0;logic [4:0] boundary_count=5;
 logic [7:0] high_threshold=96,low_threshold=32;logic [6:0] score=42;
 logic [3:0] active=0,hit_window=0,hit_led=0,trained=15;logic [3:0][3:0] countdown=0;
 wire update_ok;wire [29:0] data;wire valid,startofpacket,endofpacket;
 video_source #(.W(W),.H(H),.H_RES(80),.V_RES(64)) dut(.*);
 always @(posedge clk) begin grey<=8'(address*3);edge_pixel<=8'(address*7);end
 integer x=0,y=0,frame=0,cycles=0,cx,cy,lane,r,g,b,height;
 logic stalled=0;logic [31:0] held;
 always @(posedge clk) if(!reset) begin
  if(stalled && {startofpacket,endofpacket,data}!==held) $fatal(1,"Avalon data changed under backpressure");
  stalled=valid && !ready;held={startofpacket,endofpacket,data};
  if(valid && ready) begin
   if(startofpacket!=(x==0 && y==0) || endofpacket!=(x==79 && y==63)) $fatal(1,"packet markers");
   cx=x/2;cy=y/2;r=0;g=0;b=0;
   if(frame==0) begin r=(cx>0 && cx<W-1 && cy>0 && cy<H-1) ? ((cy*W+cx)*7)%256:0;g=r;b=r;end
   else if(frame==1) begin
    lane=-1;
    for(int i=0;i<4;i++) if(cx>boundaries[i*6+:6] && cx<boundaries[(i+1)*6+:6] && cy>=22 && cy<=28) lane=i;
    case(lane)
     0:begin r=255;g=80;b=80;end 1:begin r=80;g=255;b=80;end
     2:begin r=80;g=80;b=255;end 3:begin r=255;g=200;b=40;end
    endcase
   end else begin
    height=profile[cx*8+:8]*63/255;
    if(63-y<=height) begin r=210;g=190;b=24;end
    if(y==63-96*63/255) begin r=255;g=32;b=32;end
    if(y==63-32*63/255) begin r=32;g=180;b=255;end
    for(int i=0;i<5;i++) if(cx==boundaries[i*6+:6]) begin r=64;g=255;b=64;end
   end
   if(data!=={8'(r),2'b00,8'(g),2'b00,8'(b),2'b00}) $fatal(1,"pixel frame=%0d x=%0d y=%0d got %h",frame,x,y,data);
   if(x==79) begin x=0;if(y==63) begin y=0;frame++;view=frame==1 ? 3:2;end else y++;end else x++;
   if(frame==3) begin $display("ALL TESTS PASSED: tb_video_source");$finish;end
  end
 end
 initial begin
  boundaries[0+:6]=3;boundaries[6+:6]=10;boundaries[12+:6]=18;boundaries[18+:6]=26;boundaries[24+:6]=35;
  for(int i=0;i<40;i++) profile[i*8+:8]=i*6;
  repeat(4) @(negedge clk);reset=0;
  forever begin @(negedge clk);cycles++;ready=cycles%7!=0 && cycles%11!=0;end
 end
 initial begin #300000;$fatal(1,"watchdog");end
endmodule
