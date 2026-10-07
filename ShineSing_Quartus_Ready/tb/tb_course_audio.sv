`timescale 1ns/1ps
module tb_course_audio;
 logic clk=0;always #5 clk=~clk;
 // Use faster separate clocks with the real audio receiver and clock crossing.
 logic reset=1,bclk=0,adclrc=0,adcdat=0;
 always #11 bclk=~bclk;
 wire sample_valid;wire signed [15:0] sample;
 wire mic_valid,busy;wire [15:0] mic_sample;
 mic_load microphone(.bclk,.adclrc,.adcdat,.valid(mic_valid),.sample_data(mic_sample));
 cdc_mailbox #(.WIDTH(16)) crossing(.src_clk(bclk),.src_reset(reset),.src_valid(mic_valid),.src_data(mic_sample),.src_busy(busy),
  .dst_clk(clk),.dst_reset(reset),.dst_accept(1'b1),.dst_data(sample),.dst_valid(sample_valid));
 wire fft_valid;wire signed [15:0] fft_sample;
 audio_frontend front(.*);
 wire out_valid;wire [15:0] re,im;wire mag_valid;wire [32:0] mag;
 FFT #(.WIDTH(16)) fft(.clock(clk),.reset,.di_en(fft_valid),.di_re(fft_sample),.di_im(16'd0),.do_en(out_valid),.do_re(re),.do_im(im));
 fft_mag_sq #(.W(16)) power_stage(.clk,.reset,.fft_valid(out_valid),.fft_real(re),.fft_imag(im),.mag_sq(mag),.mag_valid);
 wire [7:0][15:0] feature;wire feature_valid;wire [8:0] peak_bin;
 audio_features features(.clk,.reset,.mag_valid,.mag,.feature,.feature_valid,.peak_bin);
 logic [15:0] pcm[0:12287],windowed[0:3071];
 integer output_count=0,frames=0;
 logic [15:0] expected_peak[0:2];
 initial $readmemh("assets/course_expected/peaks.hex",expected_peak);
 always @(negedge clk) if(!reset) begin
  if(fft_valid) begin
   if(fft_sample!==windowed[output_count]) $fatal(1,"FIR/window sample %0d expected %0d got %0d",output_count,$signed(windowed[output_count]),fft_sample);
   output_count++;
  end
  if(feature_valid) begin
   if(peak_bin!=expected_peak[frames]) $fatal(1,"course tone peak: got %0d expected %0d",peak_bin,expected_peak[frames]);
   frames++;
  end
 end
 initial begin
  $readmemh("assets/course_expected/pcm.hex",pcm);$readmemh("assets/course_expected/windowed.hex",windowed);
  repeat(64) @(negedge bclk);reset=0;
  for(int i=0;i<12288;i++) begin
   for(int bit_index=0;bit_index<64;bit_index++) begin
    @(negedge bclk);#1;
    adclrc=bit_index<32;
    adcdat=bit_index<16 ? pcm[i][15-bit_index]:0;
   end
  end
  wait(frames==3);if(output_count!=3072) $fatal(1,"lost samples");
  $display("ALL TESTS PASSED: tb_course_audio");$finish;
 end
 initial begin #30000000;$fatal(1,"watchdog");end
endmodule
