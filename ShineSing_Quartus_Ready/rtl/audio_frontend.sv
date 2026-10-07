// Filter and downsample audio using Lesson 4 logic on the FFT clock.
// Use Mini-Project 2 Q16 filter weights with signed 16-bit PCM input.
module audio_frontend #(parameter N=1024)(
 input logic clk, reset, sample_valid,
 input logic signed [15:0] sample,
 output logic fft_valid,
 output logic signed [15:0] fft_sample
);
 localparam logic signed [17:0] H[0:40]='{0,20,63,80,0,-245,-682,-1272,-1887,-2322,-2317,-1611,0,2605,6132,10336,14819,19083,22603,24925,25736,24925,22603,19083,14819,10336,6132,2605,0,-1611,-2317,-2322,-1887,-1272,-682,-245,0,80,63,20,0};
 logic signed [15:0] history[0:40];
 logic signed [39:0] sum, sum_next;
 logic signed [15:0] filtered;
 logic [5:0] tap;
 logic running;
 logic [1:0] decim;
 logic [$clog2(N)-1:0] wr, rd;
 logic write_bank, read_bank, reading;
 logic signed [32:0] window_product;
 wire [15:0] frame_q;
 wire frame_we=!reset && running && tap==40 && decim==3;
 sync_ram #(.WIDTH(16),.DEPTH(2*N),.AW($clog2(N)+1)) frame_ram(
  .clk,.we(frame_we),.waddr({write_bank,wr}),.wdata(16'(window_product >>> 15)),.raddr({read_bank,rd}),.rdata(frame_q));
 assign fft_sample=frame_q;
 logic [15:0] window_rom[0:N-1];
 initial $readmemh("assets/hamming.hex",window_rom);
 assign sum_next=sum + history[tap]*H[tap];
 always_comb begin
  // The supplied filter gain is 3.149. Keep two extra bits
  // so doubling the volume does not clip before scaling.
  if(sum_next > 40'sd8589672448) filtered=32767;
  else if(sum_next < -40'sd8589934592) filtered=-32768;
  else filtered=16'(sum_next >>> 18);
  window_product=filtered*$signed({1'b0,window_rom[wr]});
 end
 always_ff @(posedge clk) begin
  fft_valid<=0;
  if(reset) begin
   for(int i=0;i<41;i++) history[i]<=0;
   running<=0; tap<=0; sum<=0; decim<=0; wr<=0; rd<=0;
   write_bank<=0; read_bank<=0; reading<=0;
  end else begin
   if(sample_valid && !running) begin
    for(int i=40;i>0;i--) history[i]<=history[i-1];
    history[0]<=sample; running<=1; tap<=0; sum<=0;
   end
   if(running) begin
    sum<=sum_next;
    if(tap==40) begin
     running<=0; decim<=decim+1'b1;
     if(decim==3) begin
      if(wr==N-1) begin
       wr<=0; read_bank<=write_bank; write_bank<=~write_bank; rd<=0; reading<=1;
      end else wr<=wr+1'b1;
     end
    end else tap<=tap+1'b1;
   end
   if(reading) begin
    fft_valid<=1;
    if(rd==N-1) reading<=0; else rd<=rd+1'b1;
   end
  end
 end
endmodule
