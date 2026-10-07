// Set up the WM8731 using Lesson 3 settings and a 50 MHz clock enable.
// Use left-justified 16-bit audio at 48 kHz.
// The codec drives the audio clocks; MCLK is 18.432 MHz. Retry on NACK.
module codec_config #(parameter HALF_PERIOD=1250)(
 input logic clk, reset,
 output logic scl,
 inout wire sda,
 output logic configured
);
 localparam logic [15:0] CMD[0:10]='{16'h1e00,16'h00ff,16'h02ff,16'h04fd,16'h06fd,16'h083d,16'h0a00,16'h0c00,16'h0e41,16'h1002,16'h1201};
 logic [$clog2(HALF_PERIOD)-1:0] divider;
 logic [5:0] step;
 logic [3:0] command_index;
 logic release_sda, nack;
 logic [23:0] packet;
 assign sda=release_sda ? 1'bz : 1'b0;
 // Steps: 0 setup, 1 start, 2..55 send 24 bits and read 3 ACKs, 56..58 stop.
 logic [4:0] bit_number;
 logic [1:0] byte_number;
 logic [3:0] in_byte;
 always_comb begin
  bit_number=(step-6'd2)>>1; byte_number=2'(bit_number/9);in_byte=4'(bit_number%9);
 end
 always_ff @(posedge clk) begin
  if(reset) begin divider<=0;step<=0;command_index<=0;scl<=1;release_sda<=1;configured<=0;nack<=0;packet<=0;end
  else if(!configured) begin
   if(divider==HALF_PERIOD-1) begin
    divider<=0;
    if(step==0) begin scl<=1;release_sda<=1;nack<=0;packet<={8'h34,CMD[command_index]};step<=1;end
    else if(step==1) begin release_sda<=0;step<=2;end
    else if(step<56) begin
     if(!step[0]) begin
      scl<=0;
      release_sda <= (in_byte==8) ? 1'b1 : packet[23-byte_number*8-in_byte];
     end else scl<=1;
     // Read ACK when SCL falls after its high phase.
     if(step==20 || step==38) nack<=nack | sda;
     step<=step+1;
    end else if(step==56) begin nack<=nack|sda;scl<=0;release_sda<=0;step<=57;end
    else if(step==57) begin scl<=1;step<=58;end
    else begin
     release_sda<=1;step<=0;
     if(!nack) begin
      if(command_index==10) configured<=1;
      else command_index<=command_index+1;
     end
    end
   end else divider<=divider+1;
  end
 end
endmodule
