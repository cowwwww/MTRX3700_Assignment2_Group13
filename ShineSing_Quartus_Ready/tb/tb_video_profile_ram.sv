`timescale 1ns/1ps
module tb_video_profile_ram;
 localparam W=40,H=32,NMAX=16;
 logic clk=0;always #5 clk=~clk;
 logic reset=1,ready=0;logic [1:0] view=1;
 logic [7:0] grey=0,edge_pixel=0;
 wire [10:0] address;
 logic [319:0] local_average=0;logic adaptive=0,smoothing=0;
 logic [319:0] profile=0;logic [95:0] boundaries=0;logic [4:0] boundary_count=5;
 logic [7:0] high_threshold=96,low_threshold=32;logic [6:0] score=42;
 logic [3:0] active=0,hit_window=0,hit_led=0,trained=15;logic [3:0][3:0] countdown=0;
 wire [7:0] profile_value,average_value_ram;wire [$clog2(W)-1:0] profile_column;
 wire update_ok;wire [29:0] data;wire valid,startofpacket,endofpacket;
 video_source #(.W(W),.H(H),.H_RES(80),.V_RES(64),.RAM_PROFILE(1)) dut(.*);
 logic write_clk=0;always #7 write_clk=~write_clk;
 logic write_enable=0,write_bank=0;wire read_bank;
 logic publish=0;wire busy,swapped;
 cdc_mailbox #(.WIDTH(1)) mailbox(.src_clk(write_clk),.src_reset(reset),.src_valid(publish),
  .src_data(1'b1),.src_busy(busy),.dst_clk(clk),.dst_reset(reset),
  .dst_accept(update_ok),.dst_data(read_bank),.dst_valid(swapped));
 always @(negedge clk) if(!reset && swapped) begin
  if(valid) $fatal(1,"bank changed during video");
  for(int col=0;col<W;col++) begin profile[col*8+:8]=8'(col*3);local_average[col*8+:8]=8'(col*2);end
 end
 logic [5:0] write_column=0;logic [15:0] write_data=0;
 video_profile_ram #(.W(W)) ram(.write_clk,.write_enable,.write_bank,.write_column,.write_data,
  .read_clk(clk),.read_bank,.read_column(profile_column),.read_data({average_value_ram,profile_value}));
 always @(posedge clk) begin grey<=8'(address*3);edge_pixel<=8'(address*7);end
 integer x=0,y=0,frame=0,cycles=0,cx,cy,lane,r,g,b,height,hi,lo,avg;
 logic stalled=0;logic [31:0] held;
 always @(posedge clk) if(!reset) begin
  if(stalled && {startofpacket,endofpacket,data}!==held) $fatal(1,"Avalon data changed under backpressure");
  stalled=valid && !ready;held={startofpacket,endofpacket,data};
  if(valid && ready) begin
   if(startofpacket!=(x==0 && y==0) || endofpacket!=(x==79 && y==63)) $fatal(1,"packet markers");
   cx=x/2;cy=y/2;r=0;g=0;b=0;
   if(frame==0 || frame==4) begin r=(cx>=(frame==4 ? 2:1) && cx<W-(frame==4 ? 2:1) && cy>=(frame==4 ? 2:1) && cy<H-(frame==4 ? 2:1)) ? ((cy*W+cx)*7)%256:0;g=r;b=r;end
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
    avg=local_average[cx*8+:8];hi=96+(frame==3 ? avg:0);lo=32+(frame==3 ? avg:0);
    if(hi>255) hi=255;if(lo>255) lo=255;
    if(frame==3 && y==63-avg*63/255) begin r=220;g=80;b=255;end
    if(y==63-hi*63/255) begin r=255;g=32;b=32;end
    if(y==63-lo*63/255) begin r=32;g=180;b=255;end
    for(int i=0;i<5;i++) if(cx==boundaries[i*6+:6]) begin r=64;g=255;b=64;end
   end
   if(data!=={8'(r),2'b00,8'(g),2'b00,8'(b),2'b00}) $fatal(1,"pixel frame=%0d x=%0d y=%0d got %h",frame,x,y,data);
   if(x==79) begin x=0;if(y==63) begin y=0;frame++;view=frame==1 ? 3:(frame==4 ? 1:2);adaptive=frame==3;smoothing=frame==4;end else y++;end else x++;
   if(frame==5) begin if(!read_bank) $fatal(1,"bank swap missing");$display("ALL TESTS PASSED: tb_video_profile_ram");$finish;end
  end
 end
 initial begin
  boundaries[0+:6]=3;boundaries[6+:6]=10;boundaries[12+:6]=18;boundaries[18+:6]=26;boundaries[24+:6]=35;
  for(int i=0;i<40;i++) begin profile[i*8+:8]=i*6;local_average[i*8+:8]=i*5;end
  // Load bank 0, then publish a different bank during an active frame.
  for(int bank=0;bank<2;bank++) for(int col=0;col<W;col++) begin
   @(negedge write_clk);write_enable=1;write_bank=1'(bank);write_column=6'(col);
   write_data=bank==0 ? {8'(col*5),8'(col*6)}:16'hffff;
  end
  @(negedge write_clk);write_enable=0;
  repeat(4) @(negedge clk);reset=0;
  fork
   begin
    wait(frame==2 && y>10);
    for(int col=0;col<W;col++) begin
     @(negedge write_clk);write_enable=1;write_bank=1;write_column=6'(col);
     write_data={8'(col*2),8'(col*3)};
    end
    @(negedge write_clk);write_enable=0;publish=1;
    @(negedge write_clk);publish=0;
    wait(busy);wait(!busy);
    forever begin
    @(negedge write_clk);write_enable=1;write_bank=0;
    write_column=write_column==W-1 ? 0:write_column+1'b1;write_data=write_data+16'd137;
    end
   end
  join_none
  forever begin @(negedge clk);cycles++;ready=cycles%7!=0 && cycles%11!=0;end
 end
 initial begin #500000;$fatal(1,"watchdog");end
endmodule
