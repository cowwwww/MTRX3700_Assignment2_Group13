// Average the size of 256 PCM samples.
// dB = round(20log10(max(level,1))).
// Measure dB from one ADC count, not sound pressure.
module audio_level #(
    parameter BLOCK = 256,
    parameter CAL_BLOCKS = 188,
    parameter MARGIN = 64,
    parameter DB_HOLD_BLOCKS = 32
)(
    input  logic clk,
    input  logic reset,
    input  logic sample_valid,
    input  logic signed [15:0] sample,

    output logic voice,
    output logic [6:0] db,
    output logic [9:0] bar,
    output logic [15:0] level,
    output logic [15:0] noise
);

    localparam CW = $clog2(BLOCK);
    localparam DB_CW =
        (DB_HOLD_BLOCKS <= 1) ? 1 : $clog2(DB_HOLD_BLOCKS);

    logic [CW-1:0] count;
    logic [CW+16:0] acc;
    logic [15:0] amplitude;
    logic [16:0] mean_level;

    // Slow down only the HEX dB display.
    logic [DB_CW-1:0] db_hold_count;

    integer calibration;

    `include "rtl/db_thresholds.svh"

    logic [6:0] next_db;

    always_comb begin
        next_db = 0;

        for (int d = 1; d <= 90; d++) begin
            if (mean_level >= DB_THRESHOLD[d])
                next_db = 7'(d);
        end
    end

    assign amplitude =
        sample[15] ? (~sample + 16'd1) : sample;

    assign mean_level =
        (acc + amplitude) / BLOCK;

    always_ff @(posedge clk) begin
        if (reset) begin
            count         <= 0;
            acc           <= 0;
            calibration   <= 0;
            noise         <= 0;
            level         <= 0;
            voice         <= 0;
            db            <= 0;
            bar           <= 0;
            db_hold_count <= 0;
        end
        else if (sample_valid) begin

            if (count == BLOCK-1) begin

                count <= 0;
                acc   <= 0;

                // Level still updates normally.
                level <= mean_level[15:0];

                // dB display only updates every 32 blocks.
                if ((DB_HOLD_BLOCKS <= 1) ||
                    (db_hold_count == DB_HOLD_BLOCKS-1)) begin

                    db            <= next_db;
                    db_hold_count <= 0;
                end
                else begin
                    db_hold_count <= db_hold_count + 1'b1;
                end

                // LED bar still responds normally.
                for (int i = 0; i < 10; i++) begin
                    bar[i] <= mean_level >= (32 << i);
                end

                // Initial noise calibration.
                if (calibration < CAL_BLOCKS) begin
                    calibration <= calibration + 1;

                    noise <= (calibration == 0)
                        ? mean_level[15:0]
                        : 16'((7*noise + mean_level)/8);

                    voice <= 0;
                end
                else begin

                    if (!voice)
                        noise <= 16'((63*noise + mean_level)/64);

                    if (mean_level > 2*noise + MARGIN)
                        voice <= 1;
                    else if (mean_level < noise + MARGIN)
                        voice <= 0;
                end

            end
            else begin
                count <= count + 1'b1;
                acc   <= acc + amplitude;
            end
        end
    end

endmodule
