`timescale 1ns/1ps
// Run real recorded samples through the same audio path as the board.
module extract_recording_features;
 `include "build/recordings/dimensions.svh"
 logic clk=0;always #5 clk=~clk;
 logic reset=1,sample_valid=0;
 logic signed [15:0] sample=0;
 wire fft_valid;wire signed [15:0] fft_sample;
 audio_frontend front(.*);
 wire out_valid;wire [15:0] re,im;
 FFT #(.WIDTH(16)) fft(.clock(clk),.reset,.di_en(fft_valid),.di_re(fft_sample),.di_im(16'd0),.do_en(out_valid),.do_re(re),.do_im(im));
 wire mag_valid;wire [32:0] mag;
 fft_mag_sq power_stage(.clk,.reset,.fft_valid(out_valid),.fft_real(re),.fft_imag(im),.mag_sq(mag),.mag_valid);
 wire [23:0][15:0] feature;wire feature_valid;wire [8:0] peak_bin;
 audio_features #(.MODE(4),.D(24)) features(.clk,.reset,.mag_valid,.mag,.feature,.feature_valid,.peak_bin);
 logic [15:0] pcm[0:SAMPLES-1];logic [31:0] counts[0:TOKENS-1];
 integer output_file,token,received=0,offset=0,total=0;
 always @(negedge clk) if(!reset && feature_valid) begin
  $fwrite(output_file,"%0d,%096h\n",token,feature);received++;total++;
 end
 initial begin
  $readmemh("build/recordings/pcm.hex",pcm);$readmemh("build/recordings/counts.hex",counts);
  output_file=$fopen("build/recordings/features.csv","w");
  if(!output_file) $fatal(1,"cannot create feature output");
  $fwrite(output_file,"token_index,feature\n");
  for(token=0;token<TOKENS;token++) begin
   reset=1;sample_valid=0;repeat(5) @(negedge clk);reset=0;received=0;
   for(int i=0;i<counts[token]*4096;i++) begin
    @(negedge clk);sample=pcm[offset+i];sample_valid=1;
    @(negedge clk);sample_valid=0;repeat(62) @(negedge clk);
   end
   // The last FFT and feature conversion must drain in far less than 4096 clocks.
   repeat(4096) @(negedge clk);
   if(received!=counts[token]) $fatal(1,"recording %0d: got %0d frames, expected %0d",token,received,counts[token]);
   $fflush(output_file);
   repeat(5) @(negedge clk);
   offset+=counts[token]*4096;
   $display("Extracted recording %0d of %0d (%0d frames)",token+1,TOKENS,received);
  end
  if(offset!=SAMPLES) $fatal(1,"sample count mismatch");
  $fclose(output_file);
  $display("ALL TESTS PASSED: extract_recording_features");$finish;
 end
 initial begin #(64'd10000000000);$fatal(1,"watchdog");end
endmodule
