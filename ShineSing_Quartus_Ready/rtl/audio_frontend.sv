// Filter and downsample audio using Lesson 4 logic on the FFT clock.
// Use Mini-Project 2 Q16 filter weights with signed 16-bit PCM input.
module audio_frontend #(parameter N=1024)(
 input logic clk, reset, sample_valid,
 input logic signed [15:0] sample,
 output logic fft_valid,
 output logic signed [15:0] fft_sample
);
 // Use the supplied 41-tap filter from home (1).zip.
 wire [31:0] filter_data;
 wire filter_valid,filter_ready;
 wire signed [15:0] filtered = $signed(filter_data[31:16]);
 low_pass_conv #(.W(32),.W_FRAC(16),.OUTPUT_SHIFT(2)) fir(
  .clk,.reset,.x_valid(sample_valid),.x_ready(filter_ready),.x_data({sample,16'd0}),
  .y_valid(filter_valid),.y_ready(1'b1),.y_data(filter_data));
 logic [1:0] decim;
 logic [$clog2(N)-1:0] wr, rd;
 logic write_bank, read_bank, reading;
 logic signed [32:0] window_product;
 wire [15:0] frame_q;
 wire frame_we=!reset && filter_valid && decim==3;
 sync_ram #(.WIDTH(16),.DEPTH(2*N),.AW($clog2(N)+1)) frame_ram(
  .clk,.we(frame_we),.waddr({write_bank,wr}),.wdata(16'(window_product >>> 15)),.raddr({read_bank,rd}),.rdata(frame_q));
 assign fft_sample=frame_q;
 logic [15:0] window_rom[0:N-1];
 initial $readmemh("assets/hamming.hex",window_rom);
 assign window_product=filtered*$signed({1'b0,window_rom[wr]});
 always_ff @(posedge clk) begin
  fft_valid<=0;
  if(reset) begin
   decim<=0; wr<=0; rd<=0;
   write_bank<=0; read_bank<=0; reading<=0;
  end else begin
   if(filter_valid) begin
     decim<=decim+1'b1;
     if(decim==3) begin
      if(wr==N-1) begin
       wr<=0; read_bank<=write_bank; write_bank<=~write_bank; rd<=0; reading<=1;
      end else wr<=wr+1'b1;
     end
   end
   if(reading) begin
    fft_valid<=1;
    if(rd==N-1) reading<=0; else rd<=rd+1'b1;
   end
  end
 end
endmodule
