`timescale 1ns/1ps
module tb_audio_features_hd;

    localparam int NMEL = 24;

    logic clk = 0;
    always #5 clk = ~clk;

    logic reset = 1;
    logic mag_valid = 0;
    logic [32:0] mag = 0;

    wire [NMEL-1:0][15:0] feature;
    wire feature_valid;
    wire [8:0] peak_bin;

    audio_features #(
        .MODE(4),
        .D(NMEL)
    ) dut (
        .clk,
        .reset,
        .mag_valid,
        .mag,
        .feature,
        .feature_valid,
        .peak_bin
    );

    // Use the same Mel weight table as the design.
    // Calculate expected features separately below.
    `include "rtl/mel_weights.svh"

    longint unsigned mel_expected [0:NMEL-1];
    logic [15:0] expected_feature [0:NMEL-1];
    logic [15:0] reference_feature [0:NMEL-1];

    integer expected_peak;

    function automatic integer reverse10(input integer value);
        integer j;
        begin
            reverse10 = 0;
            for (j = 0; j < 10; j = j + 1)
                reverse10 = reverse10 | (((value >> j) & 1) << (9-j));
        end
    endfunction

    // Make test data shaped like a vowel sound.
    // Change harmonic spacing with fundamental to set pitch.
    // Change volume with scale.
    function automatic longint unsigned spectrum_power(
        input integer b,
        input integer fundamental,
        input integer scale
    );
        integer v;
        integer d;
        begin
            if (b <= 0 || b >= 512) begin
                spectrum_power = 0;
            end
            else begin
                // Keep a small power value so useful Mel bands are not empty.
                v = 40;

                // Add peaks at multiples of the base frequency.
                if ((b % fundamental) == 0) begin
                    v = v + 500;

                    // Add three broad peaks like those in a vowel.
                    d = (b > 45) ? (b - 45) : (45 - b);
                    if (d < 30)
                        v = v + (20000 * (30-d)) / 30;

                    d = (b > 115) ? (b - 115) : (115 - b);
                    if (d < 45)
                        v = v + (14000 * (45-d)) / 45;

                    d = (b > 220) ? (b - 220) : (220 - b);
                    if (d < 70)
                        v = v + (8000 * (70-d)) / 70;
                end

                spectrum_power = v * scale;
            end
        end
    endfunction

    task automatic build_expected(
        input integer fundamental,
        input integer scale
    );
        integer b;
        integer m;
        integer up;
        integer w;
        integer lead;
        integer frac;
        integer log_sum;
        integer log_mean;
        integer centred;
        integer log_value [0:NMEL-1];
        longint unsigned p;
        longint unsigned part;
        longint unsigned peak_power;
        begin
            for (m = 0; m < NMEL; m = m + 1) begin
                mel_expected[m] = 0;
                expected_feature[m] = 0;
                log_value[m] = 0;
            end

            peak_power = 0;
            expected_peak = 0;

            // Use bins 0..512 for the positive-frequency Mel bands.
            for (b = 0; b <= 512; b = b + 1) begin
                p = spectrum_power(b, fundamental, scale);

                if (b > 0 && b < 512 && p > peak_power) begin
                    peak_power = p;
                    expected_peak = b;
                end

                up = MEL_UP[b];
                w  = MEL_W[b];
                part = (p * w) >> 8;

                if (up < NMEL)
                    mel_expected[up] = mel_expected[up] + part;

                if (up >= 1 && up <= NMEL)
                    mel_expected[up-1] = mel_expected[up-1] + p - part;
            end

            // Match the number format used in the design:
            // Store log2 with 4 fraction bits, then remove the mean.
            log_sum = 0;
            for (m = 0; m < NMEL; m = m + 1) begin
                if (mel_expected[m] == 0) begin
                    log_value[m] = 0;
                end
                else begin
                    lead = 0;
                    for (b = 0; b <= 40; b = b + 1)
                        if ((mel_expected[m] >> b) != 0)
                            lead = b;

                    if (lead >= 4)
                        frac = (mel_expected[m] >> (lead-4)) & 15;
                    else
                        frac = (mel_expected[m] << (4-lead)) & 15;

                    log_value[m] = lead*16 + frac;
                end
                log_sum = log_sum + log_value[m];
            end

            // Match the design estimate: x/24 ~= (x*2731)>>16.
            log_mean = (log_sum * 2731) >> 16;

            for (m = 0; m < NMEL; m = m + 1) begin
                centred = 32768 + 64*(log_value[m] - log_mean);

                if (centred < 0)
                    expected_feature[m] = 16'd0;
                else if (centred > 65535)
                    expected_feature[m] = 16'hffff;
                else
                    expected_feature[m] = centred[15:0];
            end
        end
    endtask

    task automatic drive_and_check(
        input integer fundamental,
        input integer scale
    );
        integer i;
        integer b;
        integer source_bin;
        integer m;
        longint unsigned p;
        begin
            build_expected(fundamental, scale);

            // Send FFT bins in the supplied FFT order (bit-reversed).
            for (i = 0; i < 1024; i = i + 1) begin
                b = reverse10(i);

                // Copy positive-frequency values into the negative half,
                // as an FFT of real samples would do.
                if (b <= 512)
                    source_bin = b;
                else
                    source_bin = 1024 - b;

                p = spectrum_power(source_bin, fundamental, scale);

                @(negedge clk);
                mag_valid = 1;
                mag = p[32:0];

                // Check that gaps do not move the FFT bin index.
                if ((i % 37) == 0) begin
                    @(negedge clk);
                    mag_valid = 0;
                    mag = 0;
                end
            end

            @(negedge clk);
            mag_valid = 0;
            mag = 0;

            wait (feature_valid === 1'b1);
            #1;

            if (peak_bin !== expected_peak[8:0])
                $fatal(1, "HD peak bin: expected %0d, got %0d",
                       expected_peak, peak_bin);

            for (m = 0; m < NMEL; m = m + 1) begin
                if (feature[m] !== expected_feature[m])
                    $fatal(1,
                           "HD Mel band %0d: expected %0d, got %0d",
                           m, expected_feature[m], feature[m]);
            end

            @(negedge clk);
        end
    endtask

    integer m;
    integer diff;
    integer diff_sum;

    initial begin
        repeat (4) @(negedge clk);
        reset = 0;

        // Test the starting vowel data.
        drive_and_check(10, 1);
        for (m = 0; m < NMEL; m = m + 1)
            reference_feature[m] = feature[m];

        // Test the same vowel with four times the power.
        // Check that log2 and mean removal give the same features.
        drive_and_check(10, 4);
        for (m = 0; m < NMEL; m = m + 1) begin
            if (feature[m] !== reference_feature[m])
                $fatal(1,
                       "R-A4 loudness robustness failed at band %0d: %0d vs %0d",
                       m, reference_feature[m], feature[m]);
        end

        // Raise pitch by changing peak spacing from 10 to 15 bins.
        // The features may change, but the overall Mel band shape
        // should stay close to the original.
        drive_and_check(15, 1);

        diff_sum = 0;
        for (m = 0; m < NMEL; m = m + 1) begin
            if (feature[m] >= reference_feature[m])
                diff = feature[m] - reference_feature[m];
            else
                diff = reference_feature[m] - feature[m];

            diff_sum = diff_sum + diff;
        end

        if ((diff_sum / NMEL) > 700)
            $fatal(1,
                   "R-A4 pitch robustness failed: mean absolute feature difference = %0d",
                   diff_sum / NMEL);

        $display("ALL TESTS PASSED: tb_audio_features_hd");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "watchdog");
    end

endmodule
