`timescale 1ps/1ps 
module mic_load #(parameter N=16) ( 
	input bclk, // Audio bit clock from the codec (3.072 MHz on the board).
    input adclrc, 
	input adcdat, 
    // Live audio cannot pause, so this interface has valid but no ready signal.
    output logic valid, 
    output logic [N-1:0] sample_data 
); 
    // The codec must already be set to left-justified, MSB-first, N-bit audio.
 
    // Detect the start of a left-channel sample.
    logic redge_adclrc, adclrc_q;  
    always_ff @(posedge  bclk) begin : adclrc_rising_edge_ff 
        adclrc_q <= adclrc; 
    end 
    assign redge_adclrc = ~adclrc_q & adclrc; // High when ADCLRC rises.
 
    // Read the left-channel sample on rising BCLK edges.
    // When an ADCLRC rise is detected, store the first bit as the MSB.
    // Then collect the remaining bits and pulse valid after the LSB arrives.

    logic [N-1:0] temp_rx_data;
    integer bit_index;
    logic receiving;

    always_ff @(posedge bclk) begin : receive_audio_data

        // valid is only high for one BCLK cycle
        valid <= 1'b0;

        // ADCLRC rising means that this BCLK rising edge
        // is where the MSB should be sampled.
        if (redge_adclrc) begin

            // Sample the MSB immediately
            temp_rx_data[N-1] <= adcdat;

            // The MSB is stored; receive the second bit next.
            bit_index <= 1;
            receiving <= 1'b1;
        end

        else if (receiving) begin

            // Store the serial data from MSB to LSB
            temp_rx_data[(N-1)-bit_index] <= adcdat;

            // If this is the final bit (LSB)
            if (bit_index == N-1) begin

                // Use adcdat directly for the final LSB because
                // temp_rx_data[0] has not updated yet in this clock cycle
                sample_data <= {temp_rx_data[N-1:1], adcdat};

                valid <= 1'b1;
                receiving <= 1'b0;
            end

            else begin
                bit_index <= bit_index + 1;
            end
        end
    end
endmodule
