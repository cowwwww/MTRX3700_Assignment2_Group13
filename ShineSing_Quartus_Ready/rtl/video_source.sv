// Send Lesson 3 Avalon-ST video; look up the next pixel when accepted.
// Update the image, profile, game and view only between video packets.
module video_source #(parameter W=320,H=240,H_RES=640,V_RES=480,NMAX=16)(
 input logic clk,reset,
 input logic [1:0] view,
 input logic [7:0] grey,edge_pixel,
 output logic [$clog2(W*H)-1:0] address,
 input logic [W*8-1:0] profile,
 input logic [NMAX*$clog2(W)-1:0] boundaries,
 input logic [$clog2(NMAX):0] boundary_count,
 input logic [7:0] high_threshold,low_threshold,
 input logic [6:0] score,
 input logic [3:0] active,hit_window,hit_led,trained,
 input logic [3:0][3:0] countdown,
 output logic update_ok,
 output logic [29:0] data,
 output logic valid,startofpacket,endofpacket,
 input logic ready
);
 localparam XW=$clog2(W);
 logic [$clog2(H_RES)-1:0] x,nx;
 logic [$clog2(V_RES)-1:0] y,ny;
 logic [3:0] blank_count;
 logic [1:0] frame_view;
 logic [6:0] frame_score;
 logic [3:0] frame_active,frame_window,frame_hit,frame_trained;
 logic [3:0][3:0] frame_count;
 integer cx,cy,lane,height,dx,dy,digit;
 logic [7:0] r,g,b,brightness;
 logic [6:0] seg;
 logic digit_on;
 function automatic [6:0] digit_segments(input integer value);
  case(value)
   0:digit_segments=7'b0111111;1:digit_segments=7'b0000110;
   2:digit_segments=7'b1011011;3:digit_segments=7'b1001111;
   4:digit_segments=7'b1100110;5:digit_segments=7'b1101101;
   6:digit_segments=7'b1111101;7:digit_segments=7'b0000111;
   8:digit_segments=7'b1111111;default:digit_segments=7'b1101111;
  endcase
 endfunction
 assign valid=!reset && blank_count==0;
 assign update_ok=!reset && blank_count>=3;
 assign startofpacket=x==0 && y==0;
 assign endofpacket=x==H_RES-1 && y==V_RES-1;
 always_comb begin
  nx=x;ny=y;
  if(valid && ready) begin
   if(x==H_RES-1) begin nx=0;ny=y==V_RES-1 ? 0:y+1;end else nx=x+1;
  end
  address=($clog2(W*H))'((V_RES==2*H ? (ny>>1):(ny*H/V_RES))*W+(H_RES==2*W ? (nx>>1):(nx*W/H_RES)));
 end
 always_ff @(posedge clk) begin
  if(reset) begin
   x<=0;y<=0;blank_count<=8;frame_view<=0;frame_score<=0;frame_active<=0;frame_window<=0;
   frame_hit<=0;frame_count<=0;frame_trained<=0;
  end else if(blank_count!=0) begin
   blank_count<=blank_count-1;
   if(blank_count==2) begin
    frame_view<=view;frame_score<=score;frame_active<=active;frame_window<=hit_window;
    frame_hit<=hit_led;frame_count<=countdown;frame_trained<=trained;
   end
  end else if(valid && ready) begin
   x<=nx;y<=ny;
   if(endofpacket) blank_count<=8;
  end
 end
 always_comb begin
  cx=H_RES==2*W ? (x>>1):x*W/H_RES;cy=V_RES==2*H ? (y>>1):y*H/V_RES;lane=-1;
  if(boundary_count>=5 && cy>=H*7/10 && cy<=H*9/10)
   for(int i=0;i<4;i++) if(cx>boundaries[i*XW+:XW] && cx<boundaries[(i+1)*XW+:XW]) lane=i;
  r=grey;g=grey;b=grey;brightness=0;
  if(frame_view==0 && lane>=0) begin
   if(frame_hit[lane]) begin r=32;g=255;b=64;end
   else if(frame_window[lane]) begin r=255;g=24;b=24;end
   else if(frame_active[lane]) begin
    brightness=frame_count[lane]>1 ? 8'd88:8'd176;
    r=grey>>2;g=brightness;b=brightness;
   end
  end
  if(frame_view==1) begin
   // Hide border pixels because the edge filter does not write them.
   r=(cx>0 && cx<W-1 && cy>0 && cy<H-1) ? edge_pixel : 0;g=r;b=r;
  end
  height=profile[cx*8+:8]*(V_RES-1)/255;
  if(frame_view==2) begin
   r=0;g=0;b=0;
   if(V_RES-1-y<=height) begin r=210;g=190;b=24;end
   if(y==V_RES-1-high_threshold*(V_RES-1)/255) begin r=255;g=32;b=32;end
   if(y==V_RES-1-low_threshold*(V_RES-1)/255) begin r=32;g=180;b=255;end
   for(int i=0;i<NMAX;i++) if(i<boundary_count && cx==boundaries[i*XW+:XW]) begin r=64;g=255;b=64;end
  end
  if(frame_view==3) begin
   r=0;g=0;b=0;
   case(lane)
    0:begin r=255;g=80;b=80;end 1:begin r=80;g=255;b=80;end
    2:begin r=80;g=80;b=255;end 3:begin r=255;g=200;b=40;end
    default:begin end
   endcase
  end
  // Draw two score digits and four training boxes in the game view.
  digit=(x<40) ? frame_score/10 : frame_score%10;
  dx=(x<40) ? x-8:x-44;dy=y-8;seg=digit_segments(digit);digit_on=0;
  if(dx>=0 && dx<24 && dy>=0 && dy<40) begin
   digit_on=(seg[0] && dy<4 && dx>=4 && dx<20) ||
    (seg[1] && dx>=20 && dy>=4 && dy<18) || (seg[2] && dx>=20 && dy>=22 && dy<36) ||
    (seg[3] && dy>=36 && dx>=4 && dx<20) || (seg[4] && dx<4 && dy>=22 && dy<36) ||
    (seg[5] && dx<4 && dy>=4 && dy<18) || (seg[6] && dy>=18 && dy<22 && dx>=4 && dx<20);
  end
  if(frame_view==0 && x<76 && y<56) begin r=8;g=8;b=16;if(digit_on) begin r=255;g=255;b=255;end end
  if(frame_view==0 && y>=12 && y<28 && x>=96 && x<176) begin
   r=frame_trained[(x-96)/20] ? 0:180;g=frame_trained[(x-96)/20] ? 220:0;b=0;
  end
  data={r,2'b00,g,2'b00,b,2'b00};
 end
endmodule
