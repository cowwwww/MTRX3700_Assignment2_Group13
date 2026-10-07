// Bit-reversed FFT magnitude stream -> eight contiguous band energies.
// MODE 1: peak bin; MODE 2: raw energies >> RAW_SHIFT; MODE 3: Q0.16 ratios.
// Edges in bins at 12 kHz/1024: 94, 375, 750, 1172, 1641, 2344, 3281, 4453, 6000 Hz.
module audio_features #(parameter MODE=3, RAW_SHIFT=8)(
 input logic clk, reset, mag_valid,
 input logic [32:0] mag,
 output logic [7:0][15:0] feature,
 output logic feature_valid,
 output logic [8:0] peak_bin
);
 localparam int EDGE[0:8]='{8,32,64,100,140,200,280,380,512};
 logic [9:0] index, bin;
 logic [47:0] energy[0:7], total;
 logic [32:0] peak;
 logic [8:0] peak_work;
 integer band_index;
 logic [63:0] scaled;
 logic [48:0] remainder, doubled;
 logic [15:0] quotient;
 logic [4:0] divide_bit;
 // One divider shared across all eight bands; ample time between frames.
 typedef enum logic [1:0] {COLLECT, CONVERT, DIVIDE} state_t;
 state_t state;
 always_comb for(int j=0;j<10;j++) bin[j]=index[9-j];
 always_comb begin
  scaled=0;
  if(MODE==1) scaled=peak_bin;
  else if(MODE==2) scaled=energy[band_index] >> RAW_SHIFT;
  doubled=remainder<<1;
 end
 always_ff @(posedge clk) begin
  feature_valid<=0;
  if(reset) begin
   index<=0;total<=0;peak<=0;peak_work<=0;peak_bin<=0;feature<=0;
   state<=COLLECT;band_index<=0;remainder<=0;quotient<=0;divide_bit<=0;
   for(int i=0;i<8;i++) energy[i]<=0;
  end else case(state)
   COLLECT: if(mag_valid) begin
    if(bin>0 && bin<512 && mag>peak) begin peak<=mag;peak_work<=bin[8:0];end
    for(int b=0;b<8;b++) if(bin>=EDGE[b] && bin<EDGE[b+1]) energy[b]<=energy[b]+mag;
    if(bin>=EDGE[0] && bin<512) total<=total+mag;
    if(index==1023) begin
     index<=0;peak_bin<=peak_work;band_index<=0;state<=CONVERT;
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
    end else divide_bit<=divide_bit+1'b1;
   end
   default: state<=COLLECT;
  endcase
 end
endmodule
