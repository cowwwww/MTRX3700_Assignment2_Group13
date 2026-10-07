//----------------------------------------------------------------------
//  DelayBuffer: Generate Constant Delay
//----------------------------------------------------------------------
module DelayBuffer #(
    parameter   DEPTH = 32,
    parameter   WIDTH = 16
)(
    input               clock,  //  Master Clock
    input   [WIDTH-1:0] di_re,  //  Data Input (Real)
    input   [WIDTH-1:0] di_im,  //  Data Input (Imag)
    output  [WIDTH-1:0] do_re,  //  Data Output (Real)
    output  [WIDTH-1:0] do_im   //  Data Output (Imag)
);

// A2: circular RAM + output register, cycle-equivalent to DEPTH shift registers.
// The RAM contains DEPTH-1 entries because the registered read adds the last stage.
// Avoids shifting thousands of FFT registers on every idle clock in simulation.
wire [WIDTH-1:0] out_re,out_im;
assign do_re=out_re;
assign do_im=out_im;
generate if(DEPTH==1) begin: one
    reg [WIDTH-1:0] q_re,q_im;
    always @(posedge clock) begin q_re<=di_re;q_im<=di_im;end
    assign out_re=q_re;
    assign out_im=q_im;
end else begin: ring
    localparam AW=(DEPTH<=2) ? 1:$clog2(DEPTH-1);
    reg [AW-1:0] pointer=0;
    sync_ram #(.WIDTH(2*WIDTH),.DEPTH(DEPTH-1),.AW(AW)) memory(
        .clk(clock),.we(1'b1),.waddr(pointer),.raddr(pointer),.wdata({di_re,di_im}),.rdata({out_re,out_im}));
    always @(posedge clock) begin
        pointer<=pointer==DEPTH-2 ? 0:pointer+1'b1;
    end
end endgenerate

endmodule
