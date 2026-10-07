// Turn FFT power values in bit-reversed order into sound features.
// Mode 1 finds the peak bin; mode 2 adds power in each band.
// Mode 3 divides each band by total power, stored as Q0.16.
// Mode 4 uses 24 log2 Mel bands and removes their mean. Set D=24.
// Modes 1-3 band edges (Hz): 94,375,750,1172,1641,2344,3281,4453,6000.
module audio_features #(parameter MODE=3, D=8, RAW_SHIFT=8, LOG_SCALE=64)(
 input logic clk, reset, mag_valid,
 input logic [32:0] mag,
 output logic [D-1:0][15:0] feature,
 output logic feature_valid,
 output logic [8:0] peak_bin
);
 localparam int EDGE[0:8]='{8,32,64,100,140,200,280,380,512};
 localparam int NMEL=24;
 logic [9:0] index, bin;
 logic [47:0] energy[0:7], total;
 logic [32:0] peak;
 logic [8:0] peak_work;
 integer band_index;
 logic [63:0] scaled;
 logic [48:0] remainder, doubled;
 logic [15:0] quotient;
 logic [4:0] divide_bit;
 // Store values for the 24 Mel bands.
 // Mel bands are narrow at low frequencies and wider at high frequencies.
 // Each bin feeds up to two bands with weights that add to 1.
 // Share one multiplier by using w for one band and 1-w for the other.
 `include "rtl/mel_weights.svh"
 logic [40:0] mel[0:NMEL-1];       // Add 33-bit FFT power values from up to 89 bins.
 logic [4:0] mel_up;
 logic [8:0] mel_w;
 logic [41:0] mel_prod;
 logic [32:0] mel_part;
 logic [9:0] logmel[0:NMEL-1];     // Store log2 values with 6 whole bits and 4 fraction bits.
 logic [13:0] log_sum;
 logic [9:0] log_mean;
 logic [5:0] lead;
 logic [3:0] lead_frac;
 logic [9:0] log_value;
 logic signed [17:0] centred;
 // Share one divider across the eight bands.
 typedef enum logic [2:0] {COLLECT, CONVERT, DIVIDE, LOGS, MEANCALC, EMIT} state_t;
 state_t state;
 always_comb for(int j=0;j<10;j++) bin[j]=index[9-j];
 always_comb begin
  scaled=0;
  if(MODE==1) scaled=peak_bin;
  else if(MODE==2) scaled=energy[band_index] >> RAW_SHIFT;
  doubled=remainder<<1;
  // Look up the Mel weight and multiply this bin by it.
  mel_up   = bin<MEL_BINS ? MEL_UP[bin] : 5'd31;
  mel_w    = bin<MEL_BINS ? MEL_W[bin] : 9'd0;
  mel_prod = 42'(mag) * 42'(mel_w);
  mel_part = mel_prod[41:8];                 // Drop the 8 fraction bits from the weighted power.
  // Estimate log2 from the highest set bit.
  // Use the next four bits for the fraction.
  lead = 0; lead_frac = 0;
  for(int b=40;b>=0;b--) if(mel[band_index][b]) begin lead=6'(b); break; end
  if(lead>=4) lead_frac = 4'(mel[band_index] >> (lead-4));
  else        lead_frac = 4'(mel[band_index] << (4-lead));
  log_value = (mel[band_index]==0) ? 10'd0 : 10'(lead)*10'd16 + 10'(lead_frac);
  // Changing volume shifts every log2 band by the same amount.
  // Subtract the mean to reduce the effect of microphone gain.
  centred = 18'sd32768 + $signed(18'(LOG_SCALE)) * ($signed({8'd0,logmel[band_index]}) - $signed({8'd0,log_mean}));
 end
 always_ff @(posedge clk) begin
  feature_valid<=0;
  if(reset) begin
   index<=0;total<=0;peak<=0;peak_work<=0;peak_bin<=0;feature<=0;
   state<=COLLECT;band_index<=0;remainder<=0;quotient<=0;divide_bit<=0;
   log_sum<=0;log_mean<=0;
   for(int i=0;i<8;i++) energy[i]<=0;
   for(int i=0;i<NMEL;i++) begin mel[i]<=0;logmel[i]<=0;end
  end else case(state)
   COLLECT: if(mag_valid) begin
    if(bin>0 && bin<512 && mag>peak) begin peak<=mag;peak_work<=bin[8:0];end
    if(MODE==4) begin
     // Add w*mag to the upper band and (1-w)*mag to the lower band.
     if(mel_up<NMEL)               mel[mel_up]   <= mel[mel_up]   + 41'(mel_part);
     if(mel_up>=1 && mel_up<=NMEL) mel[mel_up-1] <= mel[mel_up-1] + 41'(mag) - 41'(mel_part);
    end else begin
     for(int b=0;b<8;b++) if(bin>=EDGE[b] && bin<EDGE[b+1]) energy[b]<=energy[b]+mag;
     if(bin>=EDGE[0] && bin<512) total<=total+mag;
    end
    if(index==1023) begin
     index<=0;peak_bin<=peak_work;band_index<=0;
     if(MODE==4) begin log_sum<=0;state<=LOGS;end else state<=CONVERT;
    end else index<=index+1'b1;
   end
   CONVERT: begin
    if(MODE==3) begin
     remainder<={1'b0,energy[band_index]};quotient<=0;divide_bit<=0;state<=DIVIDE;
    end else begin
    feature[band_index] <= (MODE==1 && band_index!=0) ? 16'd0 : (scaled>65535 ? 16'hffff : scaled[15:0]);
    if(band_index==7) begin
     feature_valid<=1;state<=COLLECT;total<=0;peak<=0;peak_work<=0;
     for(int b=0;b<8;b++) energy[b]<=0;
    end else band_index<=band_index+1;
    end
   end
   DIVIDE: begin
    remainder<=doubled>=total ? doubled-total:doubled;
    quotient<={quotient[14:0],doubled>=total};
    if(divide_bit==15) begin
     feature[band_index]<=total==0 ? 0 : (energy[band_index]==total ? 16'hffff : {quotient[14:0],doubled>=total});
     if(band_index==7) begin
      feature_valid<=1;state<=COLLECT;total<=0;peak<=0;peak_work<=0;
      for(int b=0;b<8;b++) energy[b]<=0;
     end else begin band_index<=band_index+1;state<=CONVERT;end
    end else divide_bit<=divide_bit+1;
   end
   // Use 24 clocks for logs, one for the mean and 24 for output.
   LOGS: begin
    logmel[band_index]<=log_value;
    log_sum<=log_sum+14'(log_value);
    if(band_index==NMEL-1) begin band_index<=0;state<=MEANCALC;end
    else band_index<=band_index+1;
   end
   // Estimate the mean without division: x/24 ~= (x*2731)>>16.
   MEANCALC: begin log_mean<=10'((26'(log_sum)*26'd2731)>>16);state<=EMIT;end
   EMIT: begin
    feature[band_index]<= centred<0 ? 16'd0 : (centred>18'sd65535 ? 16'hffff : 16'(centred));
    if(band_index==NMEL-1) begin
     feature_valid<=1;state<=COLLECT;peak<=0;peak_work<=0;
     for(int i=0;i<NMEL;i++) mel[i]<=0;
    end else band_index<=band_index+1;
   end
   default: state<=COLLECT;
  endcase
 end
endmodule
