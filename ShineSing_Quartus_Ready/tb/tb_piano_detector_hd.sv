`timescale 1ns/1ps
module tb_piano_detector_hd;

    localparam int W = 320;
    localparam int H = 240;
    localparam int PIXELS = W*H;
    localparam int NMAX = 16;
    localparam int XW = $clog2(W);
    localparam int Y0 = H*7/10;
    localparam int Y1 = H*17/20;
    localparam int MIN_GAP = 12;
    localparam int EXPECTED_WRITES = (W-4)*(H-4);

    logic clk = 0;
    always #5 clk = ~clk;

    logic reset = 1;
    logic [1:0] image_select = 2;
    logic use_sobel = 1;
    logic use_smoothing = 1;
    logic use_adaptive = 1;
    logic [7:0] high_threshold = 96;
    logic [7:0] low_threshold = 32;

    wire [$clog2(PIXELS)-1:0] rom_addr;
    logic [7:0] rom_pixel;

    logic publish_busy = 0;
    wire publish;

    logic [W*8-1:0] profile,local_average;
    wire [W*8-1:0] unused_profile,unused_average;
    wire profile_write;wire [XW-1:0] profile_column;wire [15:0] profile_values;
    integer profile_writes=0;
    always @(posedge clk) if(!reset && profile_write) begin
        if(profile_column!=profile_writes) $fatal(1,"stream column order");
        profile[profile_column*8+:8]=profile_values[7:0];
        local_average[profile_column*8+:8]=profile_values[15:8];
        profile_writes++;
    end
    wire selected_adaptive,selected_smoothing;
    wire [NMAX*XW-1:0] boundaries;
    wire [$clog2(NMAX):0] boundary_count;

    wire edge_bank;
    wire [1:0] selected_image;
    wire [7:0] selected_high;
    wire [7:0] selected_low;

    wire edge_write;
    wire [$clog2(2*PIXELS)-1:0] edge_address;
    wire [7:0] edge_value;

    piano_detector #(
        .W(W),
        .H(H),
        .MIN_GAP(MIN_GAP),
        .NMAX(NMAX),.PACKED_OUTPUT(0)
    ) dut (
        .clk,
        .reset,
        .image_select,
        .use_sobel,
        .use_smoothing,
        .use_adaptive,
        .high_threshold,
        .low_threshold,
        .rom_addr,
        .rom_pixel,
        .publish_busy,
        .publish,
        .profile(unused_profile),.local_average(unused_average),
        .profile_write,.profile_column,.profile_values,.selected_adaptive,.selected_smoothing,
        .boundaries,
        .boundary_count,
        .edge_bank,
        .selected_image,
        .selected_high,
        .selected_low,
        .edge_write,
        .edge_address,
        .edge_value
    );

    // Read the image ROM used on the board.
    // Use slot 2 for the tutor photo in the demo.
    image_store #(.W(W), .H(H)) rom (
        .analysis_clk(clk),
        .pixel_clk(clk),
        .analysis_image(selected_image),
        .display_image(2'd0),
        .analysis_address(rom_addr),
        .display_address('0),
        .analysis_pixel(rom_pixel),
        .display_pixel()
    );

    // Calculate expected results separately from piano2.hex.
    logic [7:0] ref_image [0:PIXELS-1];
    logic [7:0] blur_ref  [0:PIXELS-1];
    logic [7:0] edge_ref  [0:PIXELS-1];

    integer raw_ref [0:W-1];
    integer norm_ref [0:W-1];
    integer fwd_ref [0:W-1];
    integer avg_ref [0:W-1];

    integer key_ref [0:NMAX-1];
    integer key_strength_ref [0:NMAX-1];
    integer key_count_ref;

    bit seen [0:PIXELS-1];
    integer writes;
    integer monitor_index;
    integer monitor_bank;

    task automatic build_reference;
        integer i;
        integer x;
        integer y;
        integer s;
        integer gx;
        integer gy;
        integer agx;
        integer agy;
        integer maximum;
        integer acc;
        integer mix;
        integer back;
        integer scan;
        integer hi;
        integer lo;
        integer has_strong_peak;
        integer best;
        integer best_value;
        integer is_maximum;
        integer in_run;
        begin
            for (i = 0; i < PIXELS; i = i + 1) begin
                blur_ref[i] = 0;
                edge_ref[i] = 0;
            end

            for (x = 0; x < W; x = x + 1) begin
                raw_ref[x] = 0;
                norm_ref[x] = 0;
                fwd_ref[x] = 0;
                avg_ref[x] = 0;
            end

            for (i = 0; i < NMAX; i = i + 1) begin
                key_ref[i] = 0;
                key_strength_ref[i] = 0;
            end
            key_count_ref = 0;

            // Smooth with these 3x3 weights:
            // [1 2 1; 2 4 2; 1 2 1] / 16
            for (y = 1; y < H-1; y = y + 1) begin
                for (x = 1; x < W-1; x = x + 1) begin
                    s =
                        ref_image[(y-1)*W + (x-1)] +
                        2*ref_image[(y-1)*W + x] +
                        ref_image[(y-1)*W + (x+1)] +
                        2*ref_image[y*W + (x-1)] +
                        4*ref_image[y*W + x] +
                        2*ref_image[y*W + (x+1)] +
                        ref_image[(y+1)*W + (x-1)] +
                        2*ref_image[(y+1)*W + x] +
                        ref_image[(y+1)*W + (x+1)];

                    blur_ref[y*W + x] = (s >> 4);
                end
            end

            // Find Sobel edges after smoothing.
            // Check only x=2..W-3 and y=2..H-3 after both 3x3 filters.
            for (y = 2; y < H-2; y = y + 1) begin
                for (x = 2; x < W-2; x = x + 1) begin
                    gx =
                        blur_ref[(y-1)*W + (x+1)] +
                        2*blur_ref[y*W + (x+1)] +
                        blur_ref[(y+1)*W + (x+1)] -
                        blur_ref[(y-1)*W + (x-1)] -
                        2*blur_ref[y*W + (x-1)] -
                        blur_ref[(y+1)*W + (x-1)];

                    gy =
                        blur_ref[(y+1)*W + (x-1)] +
                        2*blur_ref[(y+1)*W + x] +
                        blur_ref[(y+1)*W + (x+1)] -
                        blur_ref[(y-1)*W + (x-1)] -
                        2*blur_ref[(y-1)*W + x] -
                        blur_ref[(y-1)*W + (x+1)];

                    agx = (gx < 0) ? -gx : gx;
                    agy = (gy < 0) ? -gy : gy;

                    s = (agx + agy) >> 2;
                    edge_ref[y*W + x] = (s > 255) ? 255 : s;

                    if (y >= Y0 && y <= Y1)
                        raw_ref[x] = raw_ref[x] + agx;
                end
            end

            // Scale the column totals to 0..255.
            maximum = 0;
            for (x = 0; x < W; x = x + 1)
                if (raw_ref[x] > maximum)
                    maximum = raw_ref[x];

            for (x = 0; x < W; x = x + 1) begin
                if (maximum == 0)
                    norm_ref[x] = 0;
                else if (raw_ref[x] == maximum)
                    norm_ref[x] = 255;
                else
                    norm_ref[x] = (raw_ref[x] * 256) / maximum;
            end

            // Average in both directions, as in the design.
            acc = norm_ref[0] << 8;
            fwd_ref[0] = norm_ref[0];

            for (x = 1; x < W; x = x + 1) begin
                mix = 31*acc + (norm_ref[x] << 8);
                acc = (mix >> 5) & 16'hffff;
                fwd_ref[x] = (mix >> 13) & 8'hff;
            end

            acc = norm_ref[W-1] << 8;
            avg_ref[W-1] = (fwd_ref[W-1] + norm_ref[W-1]) >> 1;

            for (x = W-2; x >= 0; x = x - 1) begin
                mix = 31*acc + (norm_ref[x] << 8);
                back = (mix >> 13) & 8'hff;
                avg_ref[x] = (fwd_ref[x] + back) >> 1;
                acc = (mix >> 5) & 16'hffff;
            end

            // Use local thresholds and keep peaks with enough space between them.
            scan = 0;
            while (scan < W) begin
                hi = avg_ref[scan] + high_threshold;
                lo = avg_ref[scan] + low_threshold;
                if (hi > 255) hi = 255;
                if (lo > 255) lo = 255;

                if (norm_ref[scan] == 0 || norm_ref[scan] < lo) begin
                    scan = scan + 1;
                end
                else begin
                    has_strong_peak = 0;
                    best = -1;
                    best_value = -1;
                    in_run = 1;

                    while (scan < W && in_run != 0) begin
                        hi = avg_ref[scan] + high_threshold;
                        lo = avg_ref[scan] + low_threshold;
                        if (hi > 255) hi = 255;
                        if (lo > 255) lo = 255;

                        if (norm_ref[scan] == 0 || norm_ref[scan] < lo) begin
                            in_run = 0;
                        end
                        else begin
                            if (norm_ref[scan] >= hi)
                                has_strong_peak = 1;

                            is_maximum = 0;
                            if (scan > 0 && scan < W-1)
                                is_maximum =
                                    (norm_ref[scan] > norm_ref[scan-1]) &&
                                    (norm_ref[scan] >= norm_ref[scan+1]);

                            if (is_maximum != 0 &&
                                (best < 0 || norm_ref[scan] > best_value)) begin
                                best = scan;
                                best_value = norm_ref[scan];
                            end

                            scan = scan + 1;
                        end
                    end

                    if (has_strong_peak != 0 && best >= 0) begin
                        if (key_count_ref > 0 &&
                            (best - key_ref[key_count_ref-1]) < MIN_GAP) begin

                            if (best_value >
                                key_strength_ref[key_count_ref-1]) begin
                                key_ref[key_count_ref-1] = best;
                                key_strength_ref[key_count_ref-1] = best_value;
                            end
                        end
                        else if (key_count_ref < NMAX) begin
                            key_ref[key_count_ref] = best;
                            key_strength_ref[key_count_ref] = best_value;
                            key_count_ref = key_count_ref + 1;
                        end
                    end
                end
            end
        end
    endtask

    always @(negedge clk) begin
        if (!reset && edge_write) begin
            monitor_index = edge_address % PIXELS;
            monitor_bank  = edge_address / PIXELS;

            if (monitor_index < 0 || monitor_index >= PIXELS)
                $fatal(1, "R-V4 edge address out of range");

            if (monitor_bank != edge_bank)
                $fatal(1, "R-V4 edge bank/address mismatch");

            if (seen[monitor_index])
                $fatal(1, "R-V4 duplicate edge pixel at %0d", monitor_index);

            seen[monitor_index] = 1;
            writes = writes + 1;

            if (edge_value !== edge_ref[monitor_index])
                $fatal(1,
                       "R-V4 edge pixel %0d: expected %0d, got %0d",
                       monitor_index, edge_ref[monitor_index], edge_value);
        end
    end

    integer pass;
    integer x;
    integer y;
    integer k;
    integer p;

    initial begin
        $readmemh("assets/piano2.hex", ref_image);
        build_reference();

        repeat (8) @(negedge clk);
        reset = 0;

        // Run twice without reset to catch old data left behind.
        for (pass = 0; pass < 2; pass = pass + 1) begin
            writes = 0;profile_writes=0;
            for (p = 0; p < PIXELS; p = p + 1)
                seen[p] = 0;

            wait (publish === 1'b1);
            #1;

            if (selected_image !== 2)
                $fatal(1, "R-V4 wrong selected image");

            if (selected_high !== high_threshold ||
                selected_low !== low_threshold)
                $fatal(1, "R-V4 threshold metadata mismatch");

            if(profile_writes!=W || unused_profile!==0 || unused_average!==0)
                $fatal(1,"stream count or unused packed outputs");
            // Check each column total.
            for (x = 0; x < W; x = x + 1) begin
                if (profile[x*8 +: 8] !== norm_ref[x][7:0])
                    $fatal(1,
                           "R-V4 profile column %0d: expected %0d, got %0d",
                           x, norm_ref[x], profile[x*8 +: 8]);
            end

            for (int col=0;col<W;col++)
                if(local_average[col*8+:8] !== 8'(avg_ref[col]))
                    $fatal(1,"local average mismatch at column %0d",col);
            if(!selected_adaptive || !selected_smoothing) $fatal(1,"lost HD view settings");
            // Check the key edge positions.
            if (boundary_count !== key_count_ref)
                $fatal(1,
                       "R-V4 boundary count: expected %0d, got %0d",
                       key_count_ref, boundary_count);

            if (boundary_count < 5)
                $fatal(1, "R-V4 cannot form four playable white keys");

            for (k = 0; k < key_count_ref; k = k + 1) begin
                if (boundaries[k*XW +: XW] !== key_ref[k][XW-1:0])
                    $fatal(1,
                           "R-V4 boundary %0d: expected %0d, got %0d",
                           k, key_ref[k], boundaries[k*XW +: XW]);
            end

            // Check that each valid filtered pixel was written once.
            if (writes != EXPECTED_WRITES)
                $fatal(1,
                       "R-V4 incomplete edge map: expected %0d writes, got %0d",
                       EXPECTED_WRITES, writes);

            for (y = 2; y < H-2; y = y + 1) begin
                for (x = 2; x < W-2; x = x + 1) begin
                    if (!seen[y*W + x])
                        $fatal(1,
                               "R-V4 missing edge pixel x=%0d y=%0d",
                               x, y);
                end
            end

            // Tell the detector the frame was received.
            @(negedge clk);
            publish_busy = 1;
            repeat (12) @(negedge clk);
            publish_busy = 0;
        end

        $display("R-V4 reference boundaries = %0d", key_count_ref);
        for (k = 0; k < key_count_ref; k = k + 1)
            $display("  boundary[%0d] = %0d", k, key_ref[k]);

        $display("ALL TESTS PASSED: tb_piano_detector_hd");
        $finish;
    end

    initial begin
        #40000000;
        $fatal(1, "watchdog");
    end

endmodule
