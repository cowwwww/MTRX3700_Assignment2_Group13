`timescale 1ns/1ps
// Step through the digital design; board clocks and the microphone are not simulated.
// Capture pixels from the real image, edge, clock-crossing and video logic.
// Use made-up FFT data to test features, training and the game.
// Pause the game clock while capturing each video frame.
module demo_visual;
 logic clk=0,pclk=0;
 always #10 clk=~clk;
 always #20 pclk=~pclk;
 logic reset=1,det_reset=1,hold_analysis=0;
 logic [1:0] image_select=0,view=0;
 logic use_sobel=1;
 wire [16:0] rom_addr,display_address;
 wire [7:0] rom_pixel,grey;
 wire publish,visual_busy,edge_bank,edge_write;
 wire [2559:0] profile;
 wire [143:0] boundaries;
 wire [4:0] boundary_count;
 wire [1:0] selected_image;
 wire [7:0] selected_high,selected_low,edge_value;
 wire [17:0] edge_address;
 piano_detector detector(.clk,.reset(det_reset),.image_select,.use_sobel,
  .high_threshold(8'd96),.low_threshold(8'd32),.rom_addr,.rom_pixel,
  .publish_busy(visual_busy || hold_analysis),.publish,.profile,.boundaries,
  .boundary_count,.edge_bank,.selected_image,.selected_high,.selected_low,
  .edge_write,.edge_address,.edge_value);
 wire [2727:0] visual;
 wire update_ok;
 cdc_mailbox #(.WIDTH(2728)) video_cdc(.src_clk(clk),.src_reset(reset),
  .src_valid(publish),.src_data({edge_bank,selected_image,selected_high,selected_low,boundary_count,boundaries,profile}),
  .src_busy(visual_busy),.dst_clk(pclk),.dst_reset(reset),.dst_accept(update_ok),.dst_data(visual),.dst_valid());
 wire display_bank;wire [1:0] display_image;
 wire [7:0] display_high,display_low;
 wire [4:0] display_count;wire [143:0] display_boundaries;wire [2559:0] display_profile;
 assign {display_bank,display_image,display_high,display_low,display_count,display_boundaries,display_profile}=visual;
 image_store images(.analysis_clk(clk),.pixel_clk(pclk),.analysis_image(selected_image),
  .display_image,.analysis_address(rom_addr),.display_address,.analysis_pixel(rom_pixel),.display_pixel(grey));
 logic [3:0] edge_ram[0:153599],edge_nibble;
 always @(posedge clk) if(edge_write) edge_ram[edge_address]<=edge_value[7:4];
 always @(posedge pclk) edge_nibble<=edge_ram[display_bank*76800+display_address];

 logic mag_valid=0;logic [32:0] mag=0;
 wire [7:0][15:0] feature;wire feature_valid;wire [8:0] peak_bin;
 audio_features features(.clk,.reset,.mag_valid,.mag,.feature,.feature_valid,.peak_bin);
 logic enrol=1,voice=1;logic [1:0] enrol_class=0;
 wire [3:0] trained;wire [1:0] vowel;wire [7:0] confidence;wire reject,result_valid;
 classifier #(.M(3),.DMAX(50000)) recognizer(.clk,.reset,.enable(voice),.feature_valid,.feature,
  .enrol,.enrol_class,.trained,.result(vowel),.confidence,.reject,.result_valid);
 logic run_game=1,game_enabled=0;
 wire game_clk=clk && run_game;
 wire [14:0] decision;wire decision_valid,decision_busy;
 cdc_mailbox #(.WIDTH(15)) audio_cdc(.src_clk(clk),.src_reset(reset),.src_valid(result_valid),
  .src_data({trained,(!voice || reject || enrol),confidence,vowel}),.src_busy(decision_busy),
  .dst_clk(game_clk),.dst_reset(reset),.dst_accept(1'b1),.dst_data(decision),.dst_valid(decision_valid));
 wire [6:0] score;wire [3:0] active,hit_window,hit_led;wire [3:0][3:0] countdown;
 game #(.BEAT_CLKS(2000)) game_logic(.clk(game_clk),.reset,.enable(game_enabled),
  .decision_valid,.reject(decision[10]),.confidence(decision[9:2]),.vowel(decision[1:0]),
  .score,.active,.hit_window,.hit_led,.countdown);
 wire game_busy;wire [40:0] game_display;
 cdc_mailbox #(.WIDTH(41)) game_cdc(.src_clk(clk),.src_reset(reset),.src_valid(!game_busy),
  .src_data({view,score,active,hit_window,hit_led,countdown,trained}),.src_busy(game_busy),
  .dst_clk(pclk),.dst_reset(reset),.dst_accept(update_ok),.dst_data(game_display),.dst_valid());
 wire [29:0] data;wire valid,sop,eop;
 video_source video(.clk(pclk),.reset,.view(game_display[40:39]),.grey,
  .edge_pixel({edge_nibble,edge_nibble}),.address(display_address),.profile(display_profile),
  .boundaries(display_boundaries),.boundary_count(display_count),.high_threshold(display_high),.low_threshold(display_low),
  .score(game_display[38:32]),.active(game_display[31:28]),.hit_window(game_display[27:24]),
  .hit_led(game_display[23:20]),.countdown(game_display[19:4]),.trained(game_display[3:0]),
  .update_ok,.data,.valid,.startofpacket(sop),.endofpacket(eop),.ready(1'b1));
 integer records,frame_file,game_cycles=0;
 always @(posedge game_clk) if(!reset) game_cycles++;

 task step_game(input integer cycles);
  @(negedge clk);run_game=1;
  repeat(cycles) @(negedge clk);
  run_game=0;
 endtask
 task spectrum(input integer c);
  integer bin,target;
  case(c) 0:target=16;1:target=48;2:target=80;default:target=120;endcase
  enrol_class=2'(c);
  for(int i=0;i<1024;i++) begin
   bin=0;for(int b=0;b<10;b++) bin|=((i>>b)&1)<<(9-b);
   @(negedge clk);mag_valid=1;mag=bin==target ? 33'd10000:0;
  end
  @(negedge clk);mag_valid=0;
  wait(result_valid);@(negedge clk);
  step_game(40);
  wait(!decision_busy);
 endtask
 task analyse(input integer picture,input integer mode);
  @(negedge clk);det_reset=1;hold_analysis=0;image_select=2'(picture);use_sobel=1'(mode);
  repeat(8) @(negedge clk);det_reset=0;
  wait(publish);@(negedge clk);hold_analysis=1;
  wait(!visual_busy);repeat(20) @(negedge clk);
  if(boundary_count<5) $fatal(1,"insufficient detected boundaries");
 endtask
 task capture(input string name,input integer selected_view);
  @(negedge clk);view=2'(selected_view);
  // Wait two packet ends for the clock crossing and display data to settle.
  repeat(2) begin
   do @(posedge pclk); while(!(valid && eop));
  end
  do @(posedge pclk); while(!(valid && sop));
  frame_file=$fopen({"build/demo/",name,".ppm"},"wb");
  if(!frame_file) $fatal(1,"cannot open capture");
  $fwrite(frame_file,"P6\n640 480\n255\n");
  for(int pixel=0;pixel<307200;pixel++) begin
   if($isunknown(data)) $fatal(1,"unknown RGB at pixel %0d",pixel);
   if(sop!=(pixel==0) || eop!=(pixel==307199)) $fatal(1,"packet length/markers");
   $fwrite(frame_file,"%c%c%c",data[29:22],data[19:12],data[9:2]);
   if(pixel!=307199) do @(posedge pclk); while(!valid);
  end
  $fclose(frame_file);
  $fwrite(records,"%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
   name,image_select,use_sobel,selected_view,score,active,hit_window,hit_led,trained,game_cycles);
  $display("CAPTURE %s: score=%0d active=%b window=%b hit=%b trained=%b",name,score,active,hit_window,hit_led,trained);
 endtask
 initial begin
  records=$fopen("build/demo/events.csv","w");
  if(!records) $fatal(1,"create build/demo first");
  $fwrite(records,"name,picture,sobel,view,score,active,window,hit,trained,game_cycles\n");
  repeat(16) @(negedge clk);reset=0;run_game=0;
  analyse(0,1);
  capture("01_untrained",0);
  for(int c=0;c<4;c++) repeat(4) spectrum(c);
  if(trained!==4'b1111) $fatal(1,"training incomplete");
  enrol=0;
  capture("02_ready",0);
  game_enabled=1;step_game(4005);
  if(!active[0] || countdown[0]!=2) $fatal(1,"countdown2");
  capture("03_countdown2",0);
  step_game(2000);
  if(countdown[0]!=1) $fatal(1,"countdown1");
  capture("04_countdown1",0);
  step_game(2000);
  if(!hit_window[0]) $fatal(1,"hit window missing");
  capture("05_hit_window",0);
  repeat(3) spectrum(1);
  if(score!==7'd0 || !hit_window[0]) $fatal(1,"wrong class scored");
  capture("06_wrong_vowel",0);
  repeat(3) spectrum(0);
  if(score!==7'd1 || !hit_led[0]) $fatal(1,"correct class did not score");
  capture("07_correct_vowel",0);
  repeat(3) spectrum(0);
  if(score!==7'd1) $fatal(1,"duplicate score");
  capture("08_duplicate_ignored",0);
  // Lane 1 started when lane 0 became ready to hit.
  step_game(4000);
  if(!hit_window[1]) $fatal(1,"second lane window missing");
  capture("09_second_window",0);
  step_game(2000);
  if(score!==7'd1 || active[1]) $fatal(1,"miss handling");
  capture("10_miss",0);
  for(int picture=0;picture<2;picture++) begin
   analyse(picture,0);capture($sformatf("p%0d_edge_1d",picture),1);
   analyse(picture,1);capture($sformatf("p%0d_edge_sobel",picture),1);
   capture($sformatf("p%0d_profile",picture),2);
   capture($sformatf("p%0d_masks",picture),3);
  end
  $fclose(records);
  $display("ALL TESTS PASSED: demo_visual");$finish;
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
