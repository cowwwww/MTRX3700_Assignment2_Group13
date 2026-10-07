// Mini-project raster -> 1-D/Sobel -> column profile -> refined peak picker.
// Profile uses lower white-key region. All key coordinates are measured, never stored.
// The finished profile/boundaries stay frozen until the display acknowledges them.
module piano_detector #(parameter W=320,H=240,Y0=H*7/10,Y1=H*17/20,MIN_GAP=12,NMAX=16)(
 input logic clk, reset,
 input logic [1:0] image_select,
 input logic use_sobel,
 input logic [7:0] high_threshold, low_threshold,
 output logic [$clog2(W*H)-1:0] rom_addr,
 input logic [7:0] rom_pixel,
 input logic publish_busy,
 output logic publish,
 output logic [W*8-1:0] profile,
 output logic [NMAX*$clog2(W)-1:0] boundaries,
 output logic [$clog2(NMAX):0] boundary_count,
 output logic edge_bank,
 output logic [1:0] selected_image,
 output logic [7:0] selected_high, selected_low,
 output logic edge_write,
 output logic [$clog2(2*W*H)-1:0] edge_address,
 output logic [7:0] edge_value
);
 localparam XW=$clog2(W),YW=$clog2(H);
 typedef enum logic [3:0] {WAIT_READY,CLEAR,FETCH,WAIT_ROM,FEED,DRAIN,MAXIMUM,NORM_INIT,NORM_STEP,PICK,FLUSH,PUBLISH,ACK_WAIT} state_t;
 state_t state;
 logic [XW-1:0] x;
 logic [YW-1:0] y;
 integer scan, drain, bit_count;
 logic mode;
 logic [19:0] raw_profile[0:W-1];
 logic [7:0] norm[0:W-1];
 logic [19:0] maximum;
 logic [20:0] remainder, doubled;
 logic [7:0] quotient;
 logic [7:0] previous_pixel;
 logic px_valid, sv;
 logic [11:0] gx,gy;
 logic [12:0] magnitude;
 logic [XW-1:0] sx, ex;
 logic [YW-1:0] sy, ey;
 logic ev;
 logic [11:0] strength;
 logic [7:0] display_strength;
 logic [7:0] best_value,last_value;
 logic [XW-1:0] best_position, last_position;
 logic in_region, strong_region, have_candidate;
 logic is_maximum;
 assign rom_addr=($clog2(W*H))'(y*W+x);
 assign px_valid=state==FEED;
 sobel #(.W(W),.H(H)) sobel_filter(.clk,.reset,.in_valid(px_valid),.in_pixel(rom_pixel),.in_x(x),.in_y(y),
  .out_valid(sv),.out_gx(gx),.out_gy(gy),.out_mag(magnitude),.out_x(sx),.out_y(sy));
 always_comb begin
  ev=mode ? sv : (px_valid && x>0);
  ex=mode ? sx : x; ey=mode ? sy : y;
  strength=mode ? gx : (rom_pixel>previous_pixel ? rom_pixel-previous_pixel : previous_pixel-rom_pixel);
  display_strength=mode ? (magnitude>1020 ? 8'd255 : 8'(magnitude>>2)) : strength[7:0];
  doubled=remainder<<1;
  is_maximum=0;
  if(scan>0 && scan<W-1) is_maximum=norm[scan]>norm[scan-1] && norm[scan]>=norm[scan+1];
 end
 always_ff @(posedge clk) begin
  publish<=0;edge_write<=0;
  if(reset) begin
   state<=WAIT_READY;x<=0;y<=0;scan<=0;edge_bank<=0;boundaries<=0;boundary_count<=0;
   profile<=0;selected_image<=0;selected_high<=96;selected_low<=32;
   previous_pixel<=0;maximum<=0;drain<=0;mode<=0;
  end else begin
   if(ev) begin
    edge_write<=1;edge_address<=($clog2(2*W*H))'(edge_bank*W*H+ey*W+ex);edge_value<=display_strength;
    if(ey>=Y0 && ey<=Y1) raw_profile[ex]<=raw_profile[ex]+strength;
   end
   if(px_valid) previous_pixel<=rom_pixel;
   case(state)
    WAIT_READY: if(!publish_busy) begin
     edge_bank<=~edge_bank; selected_image<=image_select==3 ? 2'd0:image_select;
     selected_high<=high_threshold;selected_low<=low_threshold;mode<=use_sobel;
     scan<=0;x<=0;y<=0;maximum<=0;state<=CLEAR;
    end
    CLEAR: begin
     raw_profile[scan]<=0;
     if(scan==W-1) begin scan<=0;state<=FETCH;end else scan<=scan+1;
    end
    FETCH: state<=WAIT_ROM;
    WAIT_ROM: state<=FEED;
    FEED: begin
     if(x==W-1) begin
      x<=0;
      if(y==H-1) begin drain<=0;state<=DRAIN;end
      else begin y<=y+1'b1;state<=FETCH;end
     end else begin x<=x+1'b1;state<=FETCH;end
    end
    DRAIN: if(drain==8) begin scan<=0;state<=MAXIMUM;end else drain<=drain+1;
    MAXIMUM: begin
     if(raw_profile[scan]>maximum) maximum<=raw_profile[scan];
     if(scan==W-1) begin scan<=0;state<=NORM_INIT;end else scan<=scan+1;
    end
    NORM_INIT: begin remainder<={1'b0,raw_profile[scan]};quotient<=0;bit_count<=0;state<=NORM_STEP;end
    NORM_STEP: begin
     remainder<=doubled>=maximum ? doubled-maximum : doubled;
     quotient<={quotient[6:0],doubled>=maximum};
     if(bit_count==7) begin
      norm[scan]<=maximum==0 ? 0 : (raw_profile[scan]==maximum ? 255 : {quotient[6:0],doubled>=maximum});
      profile[scan*8+:8]<=maximum==0 ? 0 : (raw_profile[scan]==maximum ? 255 : {quotient[6:0],doubled>=maximum});
      if(scan==W-1) begin
       scan<=0;boundary_count<=0;boundaries<=0;in_region<=0;strong_region<=0;
       have_candidate<=0;best_value<=0;last_value<=0;last_position<=0;state<=PICK;
      end else begin scan<=scan+1;state<=NORM_INIT;end
     end else bit_count<=bit_count+1;
    end
    PICK: begin
     if(norm[scan]>=selected_low && norm[scan]!=0) begin
      in_region<=1;
      if(norm[scan]>=selected_high) strong_region<=1;
      if(is_maximum && (!have_candidate || norm[scan]>best_value)) begin
       best_value<=norm[scan];best_position<=XW'(scan);have_candidate<=1;
      end
     end else if(in_region) begin
      if(strong_region && have_candidate) begin
       if(boundary_count!=0 && best_position-last_position<MIN_GAP) begin
        if(best_value>last_value) begin
         boundaries[(boundary_count-1)*XW+:XW]<=best_position;last_position<=best_position;last_value<=best_value;
        end
       end else if(boundary_count<NMAX) begin
        boundaries[boundary_count*XW+:XW]<=best_position;boundary_count<=boundary_count+1'b1;
        last_position<=best_position;last_value<=best_value;
       end
      end
      in_region<=0;strong_region<=0;have_candidate<=0;best_value<=0;
     end
     if(scan==W-1) state<=FLUSH;else scan<=scan+1;
    end
    FLUSH: begin
     // Trailing region: same spacing rule, even at the final image column.
     if(in_region && strong_region && have_candidate) begin
      if(boundary_count!=0 && best_position-last_position<MIN_GAP) begin
       if(best_value>last_value) boundaries[(boundary_count-1)*XW+:XW]<=best_position;
      end else if(boundary_count<NMAX) begin
       boundaries[boundary_count*XW+:XW]<=best_position;boundary_count<=boundary_count+1'b1;
      end
     end
     state<=PUBLISH;
    end
    PUBLISH: if(!publish_busy) begin publish<=1;state<=ACK_WAIT;end
    ACK_WAIT: if(publish_busy) state<=WAIT_READY;
    default: state<=WAIT_READY;
   endcase
  end
 end
endmodule
