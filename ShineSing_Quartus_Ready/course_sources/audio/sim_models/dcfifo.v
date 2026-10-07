`timescale 1 ps / 1 ps
// dcfifo -- behavioural simulation model of the Intel dual-clock FIFO (show-ahead mode), for Verilator/ModelSim
// runs without the Altera simulation libraries. Pointers are compared directly (no synchroniser delay), which is
// optimistic by a few clocks compared with the real megafunction but functionally the same: writes are dropped
// when full, reads are ignored when empty, q shows the next word before rdreq (show-ahead).
module dcfifo ( data, rdclk, wrclk, aclr, rdreq, wrreq,
                eccstatus, rdfull, wrfull, rdempty, wrempty, rdusedw, wrusedw, q);
    parameter lpm_width = 1;
    parameter lpm_widthu = 1;
    parameter lpm_numwords = 2;
    parameter delay_rdusedw = 1;
    parameter delay_wrusedw = 1;
    parameter rdsync_delaypipe = 0;
    parameter wrsync_delaypipe = 0;
    parameter intended_device_family = "Stratix";
    parameter lpm_showahead = "OFF";
    parameter underflow_checking = "ON";
    parameter overflow_checking = "ON";
    parameter clocks_are_synchronized = "FALSE";
    parameter use_eab = "ON";
    parameter add_ram_output_register = "OFF";
    parameter lpm_hint = "USE_EAB=ON";
    parameter lpm_type = "dcfifo";
    parameter add_usedw_msb_bit = "OFF";
    parameter read_aclr_synch = "OFF";
    parameter write_aclr_synch = "OFF";
    parameter enable_ecc = "FALSE";
    parameter add_width = 1;
    parameter ram_block_type = "AUTO";

    input [lpm_width-1:0] data;
    input rdclk, wrclk, aclr, rdreq, wrreq;
    output rdfull, wrfull, rdempty, wrempty;
    output [lpm_widthu-1:0] rdusedw, wrusedw;
    output [lpm_width-1:0] q;
    output [1:0] eccstatus;

    reg [lpm_width-1:0] mem [0:lpm_numwords-1];
    reg [lpm_widthu:0] wptr = 0, rptr = 0;                 // one extra bit distinguishes full from empty
    wire [lpm_widthu:0] used = wptr - rptr;
    wire full  = (used == lpm_numwords);
    wire empty = (used == 0);
    assign rdfull = full;  assign wrfull = full;
    assign rdempty = empty; assign wrempty = empty;
    assign rdusedw = used[lpm_widthu-1:0]; assign wrusedw = used[lpm_widthu-1:0];
    assign eccstatus = 2'b00;
    reg [lpm_width-1:0] q_reg;
    assign q = (lpm_showahead == "ON") ? mem[rptr[lpm_widthu-1:0]] : q_reg;

    always @(posedge wrclk or posedge aclr) begin
        if (aclr) wptr <= 0;
        else if (wrreq && !full) begin mem[wptr[lpm_widthu-1:0]] <= data; wptr <= wptr + 1'b1; end
    end
    always @(posedge rdclk or posedge aclr) begin
        if (aclr) rptr <= 0;
        else if (rdreq && !empty) begin q_reg <= mem[rptr[lpm_widthu-1:0]]; rptr <= rptr + 1'b1; end
    end
    initial $display("dcfifo (behavioural sim model): %0d x %0d, show-ahead %s", lpm_numwords, lpm_width, lpm_showahead);
endmodule
