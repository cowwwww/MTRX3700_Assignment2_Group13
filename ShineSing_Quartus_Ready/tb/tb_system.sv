`timescale 1ns/1ps
// Integration at the FFT magnitude interface; tb_audio_pipeline independently
// checks PCM -> FIR -> Hamming -> actual 1024-point FFT -> this same interface.
module tb_system;
 logic clk=0,pclk=0;always #5 clk=~clk;always #8 pclk=~pclk;
 logic reset=1,mag_valid=0;logic [32:0] mag=0;
 wire [7:0][15:0] feature;wire feature_valid;wire [8:0] peak_bin;
 audio_features features(.*);
 logic enrol=1;logic [1:0] enrol_class=0;
 wire [3:0] trained;wire [1:0] result;wire [7:0] confidence;wire reject,result_valid;
 classifier #(.NT(1),.M(3),.DMAX(10000)) recognizer(.clk,.reset,.enable(1'b1),.feature_valid,.feature,.enrol,.enrol_class,.trained,.result,.confidence,.reject,.result_valid);
 wire [6:0] score;wire [3:0] active,hit_window,hit_led;wire [3:0][3:0] countdown;
 game #(.BEAT_CLKS(2000)) game_logic(.clk,.reset,.enable((&trained) && !enrol),.decision_valid(result_valid),.vowel(result),.confidence,.reject,.score,.active,.hit_window,.hit_led,.countdown);
 localparam W=64,H=24,XW=6,NMAX=16;
 wire [10:0] rom_addr;logic [7:0] rom_pixel;
 wire publish,busy;wire [511:0] profile;wire [95:0] boundaries;wire [4:0] boundary_count;
 wire edge_bank,edge_write;wire [1:0] selected_image;wire [7:0] selected_high,selected_low,edge_value;wire [11:0] edge_address;
 piano_detector #(.W(W),.H(H),.MIN_GAP(4)) detector(.clk,.reset,.image_select(2'd0),.use_sobel(1'b0),.high_threshold(8'd96),.low_threshold(8'd32),
  .rom_addr,.rom_pixel,.publish_busy(busy),.publish,.profile,.boundaries,.boundary_count,.edge_bank,.selected_image,.selected_high,.selected_low,.edge_write,.edge_address,.edge_value);
 always @(posedge clk) rom_pixel <= (rom_addr%W>=4 && rom_addr%8==4) ? 8'd10:8'd240;
 wire [612:0] visual;wire updated,update_ok;
 cdc_mailbox #(.WIDTH(613)) transfer(.src_clk(clk),.src_reset(reset),.src_valid(publish),.src_data({boundary_count,boundaries,profile}),.src_busy(busy),
  .dst_clk(pclk),.dst_reset(reset),.dst_accept(update_ok),.dst_data(visual),.dst_valid(updated));
 wire [10:0] address;logic [7:0] grey=240;
 wire [29:0] data;wire valid,sop,eop;
 // Image/game pipelines run concurrently; gameplay CDC is checked separately.
 video_source #(.W(W),.H(H),.H_RES(128),.V_RES(48)) video(.clk(pclk),.reset,.view(2'd3),.grey,.edge_pixel(8'd0),.address,
  .profile(visual[511:0]),.boundaries(visual[607:512]),.boundary_count(visual[612:608]),.high_threshold(8'd96),.low_threshold(8'd32),
  .score(7'd0),.active(4'd0),.hit_window(4'd0),.hit_led(4'd0),.trained(4'd0),.countdown(16'd0),.update_ok,.data,.valid,.startofpacket(sop),.endofpacket(eop),.ready(1'b1));
 integer frames=0,coloured=0;
 always @(posedge pclk) if(!reset && valid) begin
  if(eop) frames++;
  if(data!=0) coloured++;
 end
 task spectral_frame(input integer c);
  integer bin,target;
  case(c) 0:target=16;1:target=48;2:target=80;default:target=120;endcase
  for(int i=0;i<1024;i++) begin
   bin=0;for(int b=0;b<10;b++) bin=bin|(((i>>b)&1)<<(9-b));
   @(negedge clk);mag_valid=1;mag=bin==target ? 32'd10000:0;
  end
  @(negedge clk);mag_valid=0;wait(result_valid);@(negedge clk);
 endtask
 initial begin
  repeat(8) @(negedge clk);reset=0;
  for(int c=0;c<4;c++) begin enrol_class=c;spectral_frame(c);end
  if(trained!=15) $fatal(1,"system training");
  enrol=0;wait(hit_window[0]);spectral_frame(0);repeat(4) @(negedge clk);
  if(score!=1) $fatal(1,"audio classification did not score note: %0d",score);
  wait(frames>=3);
  if(visual[612:608]<5 || coloured==0) $fatal(1,"image-to-mask integration failed");
  $display("ALL TESTS PASSED: tb_system");$finish;
 end
 initial begin #500000;$fatal(1,"watchdog");end
endmodule
