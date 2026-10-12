// Use A1 lane states and scoring; equal countdowns keep hit times separate.
module game #(parameter BEAT_CLKS=25000000)(
 input logic clk, reset, enable,
 input logic decision_valid, reject,
 input logic [7:0] confidence,
 input logic [1:0] vowel,
 output logic [6:0] score,
 output logic [3:0] active, hit_window, hit_led,
 output logic [3:0][3:0] countdown
);
 integer beat_counter;
 wire tick=enable && beat_counter==BEAT_CLKS-1;
 always_ff @(posedge clk)
  if(reset || !enable) beat_counter<=0;
  else if(tick) beat_counter<=0;
  else beat_counter<=beat_counter+1;
 wire [3:0] spawn, hit;
 wire [3:0] start_count;
 game_controller controller(.clk,.reset(reset || !enable),.beat_tick(tick),
  .random_value(11'd0),.lane_active(active),.hit_pulse(hit),.spawn,.start_count,.score);
 genvar l;
 generate for(l=0;l<4;l=l+1) begin: lanes
  wire press=decision_valid && !reject && confidence>=76 && vowel==l && hit_window[l];
  reaction_time_fsm #(.CLKS_PER_MS(1),.LED_FLASH_MS(BEAT_CLKS)) lane(
   .clk,.reset(reset || !enable),.beat_tick(tick),.spawn(spawn[l]),.start_count,
   .button_pressed(press),.lane_active(active[l]),.lane_value(countdown[l]),
   .hit_pulse(hit[l]),.led_on(hit_led[l]));
  assign hit_window[l]=active[l] && countdown[l]==0;
 end
 endgenerate
endmodule
