module shine_sing_top #(parameter bit CAPTURE_MODE=0)(
 input wire CLOCK_50,
 input wire [9:0] SW,
 input wire [3:0] KEY,
 input wire AUD_ADCDAT,AUD_ADCLRCK,AUD_BCLK,
 output wire AUD_XCK,AUD_DACDAT,
 output wire FPGA_I2C_SCLK,
 inout wire FPGA_I2C_SDAT,
 output wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,
 output wire [9:0] LEDR,
 output wire VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N,
 output wire [7:0] VGA_R,VGA_G,VGA_B
);
 `include "rtl/templates.svh"
 localparam W=320,H=240,XW=9,NMAX=16,CW=$clog2(NMAX)+1;
 wire fft_clk,pixel_clk,audio_locked,video_locked;
 adc_pll audio_pll(.areset(1'b0),.inclk0(CLOCK_50),.c0(fft_clk),.locked(audio_locked));
 video_pll pixel_pll(.refclk(CLOCK_50),.rst(1'b0),.outclk_0(pixel_clk),.locked(video_locked));
 assign AUD_XCK=fft_clk;assign AUD_DACDAT=0;
 wire arst=~KEY[0] | ~audio_locked | ~video_locked;
 wire r50,rf,rp,ra;
 reset_sync reset50(.clk(CLOCK_50),.arst,.reset(r50));
 reset_sync resetfft(.clk(fft_clk),.arst,.reset(rf));
 reset_sync resetpixel(.clk(pixel_clk),.arst,.reset(rp));
 reset_sync resetaudio(.clk(AUD_BCLK),.arst,.reset(ra));
 wire configured;
 codec_config codec(.clk(CLOCK_50),.reset(r50),.scl(FPGA_I2C_SCLK),.sda(FPGA_I2C_SDAT),.configured);
 wire [9:0] switches;
 wire enrol;
 wire [7:0] hi,lo;
 board_controls controls(.clk(CLOCK_50),.reset(r50),.sw(SW),.key(KEY),.switches,.enrol,.high_threshold(hi),.low_threshold(lo));
 wire [2:0] training;
 wire control_busy;
 cdc_mailbox #(.WIDTH(3)) control_cdc(.src_clk(CLOCK_50),.src_reset(r50),.src_valid(!control_busy),
  .src_data({enrol,switches[7:6]}),.src_busy(control_busy),.dst_clk(fft_clk),.dst_reset(rf),.dst_accept(1'b1),.dst_data(training),.dst_valid());
 wire [15:0] pcm,pcm_fft;
 wire pcm_valid,pcm_fft_valid,pcm_busy;
 mic_load microphone(.bclk(AUD_BCLK),.adclrc(AUD_ADCLRCK),.adcdat(AUD_ADCDAT),.sample_data(pcm),.valid(pcm_valid));
 cdc_mailbox #(.WIDTH(16)) audio_cdc(.src_clk(AUD_BCLK),.src_reset(ra),.src_valid(pcm_valid),.src_data(pcm),.src_busy(pcm_busy),
  .dst_clk(fft_clk),.dst_reset(rf),.dst_accept(1'b1),.dst_data(pcm_fft),.dst_valid(pcm_fft_valid));
 wire [15:0] fft_input;
 wire fft_input_valid;
 audio_frontend frontend(.clk(fft_clk),.reset(rf),.sample_valid(pcm_fft_valid),.sample(pcm_fft),.fft_valid(fft_input_valid),.fft_sample(fft_input));
 wire [15:0] re,im;
 wire fft_output_valid,mag_valid;
 wire [32:0] mag;
 FFT #(.WIDTH(16)) fft(.clock(fft_clk),.reset(rf),.di_en(fft_input_valid),.di_re(fft_input),.di_im(16'd0),.do_en(fft_output_valid),.do_re(re),.do_im(im));
 fft_mag_sq #(.W(16)) power_stage(.clk(fft_clk),.reset(rf),.fft_valid(fft_output_valid),.fft_real(re),.fft_imag(im),.mag_sq(mag),.mag_valid);
wire [23:0][15:0] feature;
 wire feature_valid;
 wire [8:0] peak;
  audio_features #(.MODE(4),.D(24)) features(.clk(fft_clk),.reset(rf),.mag_valid,.mag,.feature,.feature_valid,.peak_bin(peak));
 wire voice;
 wire [6:0] db;
 wire [9:0] bar;
 wire [15:0] level,noise;
 audio_level meter(.clk(fft_clk),.reset(rf),.sample_valid(pcm_fft_valid),.sample(pcm_fft),.voice,.db,.bar,.level,.noise);
 wire [1:0] vowel;
 wire [7:0] confidence;
 wire reject,result_valid;
 wire [3:0] trained;
 classifier #(.D(24),.M(3),.DMAX(65000),.PRETRAINED(!CAPTURE_MODE),
  .SAVED_CLASSES({4{TEMPLATES_READY}}),.SAVED_TEMPLATES(TEMPLATES)) recognizer(.clk(fft_clk),.reset(rf),.enable(voice),.feature_valid,.feature,
  .enrol(CAPTURE_MODE && training[2]),.enrol_class(training[1:0]),.trained,.result(vowel),.confidence,.reject,.result_valid);
 // Keep HEX and LEDs on the FFT clock; send game events to 50 MHz.
 hex_seg h0(.d(4'(db%10)),.blank(1'b0),.seg(HEX0));
 hex_seg h1(.d(4'(db/10)),.blank(1'b0),.seg(HEX1));
 hex_seg h2(.d({2'b0,vowel}),.blank(!voice || reject || (CAPTURE_MODE && training[2])),.seg(HEX2));
 hex_seg h3(.d(4'(peak%10)),.blank(1'b0),.seg(HEX3));
 hex_seg h4(.d(4'((peak/10)%10)),.blank(1'b0),.seg(HEX4));
 hex_seg h5(.d(4'(peak/100)),.blank(1'b0),.seg(HEX5));
 assign LEDR=bar;
 wire [14:0] decision;
 wire decision_valid;
 cdc_mailbox #(.WIDTH(15)) decision_cdc(.src_clk(fft_clk),.src_reset(rf),.src_valid(result_valid),
  .src_data({trained,(!voice || reject || (CAPTURE_MODE && training[2])),confidence,vowel}),.src_busy(),
  .dst_clk(CLOCK_50),.dst_reset(r50),.dst_accept(1'b1),.dst_data(decision),.dst_valid(decision_valid));
 wire [6:0] score;
 wire [3:0] active,hit_window,hit_led;
 wire [3:0][3:0] countdown;
 wire [CW-1:0] nbound;
 wire publish,publish_busy,bank,edge_write;
 logic keys_ready;
 always_ff @(posedge CLOCK_50)
  if(r50) keys_ready<=0;else if(publish) keys_ready<=nbound>=5;
 game game_logic(.clk(CLOCK_50),.reset(r50),.enable(keys_ready && (&decision[14:11]) && !(CAPTURE_MODE && enrol)),
  .decision_valid,.reject(decision[10]),.confidence(decision[9:2]),.vowel(decision[1:0]),.score,.active,.hit_window,.hit_led,.countdown);
 wire [16:0] analysis_address,display_address;
 wire [7:0] analysis_pixel,display_pixel;
 wire [1:0] selected_image,display_image;
 image_store images(.analysis_clk(CLOCK_50),.pixel_clk,.analysis_image(selected_image),.display_image,
  .analysis_address,.display_address,.analysis_pixel,.display_pixel);
 wire [17:0] edge_address;
 wire [7:0] edge_value,selected_high,selected_low;
 wire [W*8-1:0] profile,local_average;
 wire selected_adaptive,selected_smoothing;
 wire [NMAX*XW-1:0] boundaries;
 // SW8 smooths the image; SW9 uses local thresholds.
 piano_detector detector(.clk(CLOCK_50),.reset(r50),.image_select(switches[4:3]),.use_sobel(switches[5]),
  .use_smoothing(switches[8]),.use_adaptive(switches[9]),
  .high_threshold(hi),.low_threshold(lo),.rom_addr(analysis_address),.rom_pixel(analysis_pixel),.publish_busy,.publish,
  .profile,.local_average,.selected_adaptive,.selected_smoothing,.boundaries,.boundary_count(nbound),.edge_bank(bank),.selected_image,.selected_high,.selected_low,
  .edge_write,.edge_address,.edge_value);
 localparam VW=3+2+16+CW+NMAX*XW+W*16;
 wire [VW-1:0] visual;
 wire update_ok;
 cdc_mailbox #(.WIDTH(VW)) video_cdc(.src_clk(CLOCK_50),.src_reset(r50),.src_valid(publish),
  .src_data({selected_adaptive,selected_smoothing,local_average,bank,selected_image,selected_high,selected_low,nbound,boundaries,profile}),.src_busy(publish_busy),
  .dst_clk(pixel_clk),.dst_reset(rp),.dst_accept(update_ok),.dst_data(visual),.dst_valid());
 wire display_bank,display_adaptive,display_smoothing;
 wire [W*8-1:0] display_average;
 wire [7:0] display_high,display_low;
 wire [CW-1:0] display_count;
 wire [NMAX*XW-1:0] display_boundaries;
 wire [W*8-1:0] display_profile;
 assign {display_adaptive,display_smoothing,display_average,display_bank,display_image,display_high,display_low,display_count,display_boundaries,display_profile}=visual;
 // Store 4-bit display pixels to save 75 M10Ks; detect edges with 12-bit Gx.
 logic [3:0] edges[0:2*W*H-1],edge_nibble;
 wire [7:0] edge_pixel={edge_nibble,edge_nibble};
 always_ff @(posedge CLOCK_50) if(edge_write) edges[edge_address]<=edge_value[7:4];
 always_ff @(posedge pixel_clk) edge_nibble<=edges[display_bank*W*H+display_address];
 wire game_busy;
 wire [40:0] game_display;
 cdc_mailbox #(.WIDTH(41)) game_cdc(.src_clk(CLOCK_50),.src_reset(r50),.src_valid(!game_busy),
  .src_data({switches[2:1],score,active,hit_window,hit_led,countdown,decision[14:11]}),.src_busy(game_busy),
  .dst_clk(pixel_clk),.dst_reset(rp),.dst_accept(update_ok),.dst_data(game_display),.dst_valid());
 wire [29:0] st_data;
 wire st_valid,st_sop,st_eop,st_ready;
 video_source source(.clk(pixel_clk),.reset(rp),.view(game_display[40:39]),.grey(display_pixel),.edge_pixel,.address(display_address),
  .profile(display_profile),.local_average(display_average),.adaptive(display_adaptive),.smoothing(display_smoothing),.boundaries(display_boundaries),.boundary_count(display_count),.high_threshold(display_high),.low_threshold(display_low),
  .score(game_display[38:32]),.active(game_display[31:28]),.hit_window(game_display[27:24]),.hit_led(game_display[23:20]),
  .countdown(game_display[19:4]),.trained(game_display[3:0]),.update_ok,.data(st_data),.valid(st_valid),.startofpacket(st_sop),.endofpacket(st_eop),.ready(st_ready));
 vga_sink vga(.clk_clk(pixel_clk),.reset_reset_n(~rp),.video_in_data(st_data),.video_in_startofpacket(st_sop),
  .video_in_endofpacket(st_eop),.video_in_valid(st_valid),.video_in_ready(st_ready),.vga_CLK(VGA_CLK),.vga_HS(VGA_HS),.vga_VS(VGA_VS),
  .vga_BLANK(VGA_BLANK_N),.vga_SYNC(VGA_SYNC_N),.vga_R(VGA_R),.vga_G(VGA_G),.vga_B(VGA_B));
endmodule
