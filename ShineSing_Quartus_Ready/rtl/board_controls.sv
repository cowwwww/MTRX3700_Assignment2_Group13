module board_controls #(parameter DEBOUNCE=1000000)(
 input logic clk,reset,
 input logic [9:0] sw,
 input logic [3:0] key,
 output logic [9:0] switches,
 output logic enrol,
 output logic [7:0] high_threshold,low_threshold
);
 (* async_reg="true" *) logic [12:0] sync1,sync2;
 logic [12:0] stable,candidate;
 integer count;
 always_ff @(posedge clk) begin
  sync1<={~key[3:1],sw};sync2<=sync1;
  if(reset) begin stable<=0;candidate<=0;count<=0;high_threshold<=96;low_threshold<=32;end
  else begin
   if(sync2!=candidate) begin candidate<=sync2;count<=0;end
   else if(count<DEBOUNCE) count<=count+1;
   else if(stable!=candidate) begin
    stable<=candidate;
    if(candidate[10] && !stable[10]) begin
     if(candidate[0]) begin if(low_threshold+8<high_threshold) low_threshold<=low_threshold+8;end
     else if(high_threshold<247) high_threshold<=high_threshold+8;
    end
    if(candidate[11] && !stable[11]) begin
     if(candidate[0]) begin if(low_threshold>8) low_threshold<=low_threshold-8;end
     else if(high_threshold>low_threshold+8) high_threshold<=high_threshold-8;
    end
   end
  end
 end
 assign switches=stable[9:0];assign enrol=stable[12];
endmodule
