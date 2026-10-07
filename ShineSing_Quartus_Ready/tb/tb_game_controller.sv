`timescale 1ns/1ps

module tb_game_controller;
    logic clk = 0;
    logic reset, beat_tick;
    logic [10:0] random_value;
    logic [3:0] lane_active, hit_pulse;
    wire [3:0] spawn, start_count;
    wire [6:0] score;
    integer i;

    game_controller DUT (
        .clk(clk),
        .reset(reset),
        .beat_tick(beat_tick),
        .random_value(random_value),
        .lane_active(lane_active),
        .hit_pulse(hit_pulse),
        .spawn(spawn),
        .start_count(start_count),
        .score(score)
    );

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, tb_game_controller);
    end

    task tick;
        begin
            #5 clk = 1;
            #1;
            clk = 0;
            #4;
        end
    endtask

    task beat;
        begin
            beat_tick = 1;
            tick;
            beat_tick = 0;
            tick;
        end
    endtask

    initial begin
        reset = 1; beat_tick = 0; random_value = 11'd203;
        lane_active = 0; hit_pulse = 0;
        tick;
        reset = 0;

        beat;
        if (spawn !== 0) $fatal(1, "note spawned too early");

        beat_tick = 1;
        tick;
        if (spawn !== 4'b0001) $fatal(1, "first note should spawn on lane 0");
        if (start_count < 2 || start_count > 5) $fatal(1, "start count is outside 2 to 5");
        beat_tick = 0;
        tick;
        if (spawn !== 0) $fatal(1, "spawn was not a one clock pulse");

        // The controller skips a busy selected lane, then advances round-robin.
        lane_active = 4'b0010;
        beat;
        beat_tick = 1;
        tick;
        if (spawn !== 4'b0000) $fatal(1, "controller spawned into busy lane 1");
        beat_tick = 0;
        tick;

        lane_active = 4'b0000;
        beat;
        beat_tick = 1;
        tick;
        if (spawn !== 4'b0100) $fatal(1, "round-robin did not advance to lane 2");
        beat_tick = 0;
        tick;

        // Two hits in one cycle should add two points.
        hit_pulse = 4'b0011;
        tick;
        hit_pulse = 0;
        if (score !== 2) $fatal(1, "two simultaneous hits were scored incorrectly");

        // Check the defined overflow behaviour: saturate at 99.
        for (i = 0; i < 60; i = i + 1) begin
            hit_pulse = 4'b0011;
            tick;
        end
        hit_pulse = 0;
        tick;
        if (score !== 99) $fatal(1, "score did not saturate at 99");

        reset = 1;
        tick;
        if (score !== 0 || spawn !== 0) $fatal(1, "reset did not clear controller state");

        $display("ALL TESTS PASSED: tb_game_controller");
        $finish;
    end
endmodule
