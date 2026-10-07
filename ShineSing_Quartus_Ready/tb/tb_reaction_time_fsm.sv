`timescale 1ns/1ps

module tb_reaction_time_fsm;
    logic clk = 0;
    logic reset, beat_tick, spawn, button_pressed;
    logic [3:0] start_count;
    wire lane_active, hit_pulse, led_on;
    wire [3:0] lane_value;

    reaction_time_fsm #(.CLKS_PER_MS(1), .LED_FLASH_MS(3)) DUT (
        .clk(clk),
        .reset(reset),
        .beat_tick(beat_tick),
        .spawn(spawn),
        .start_count(start_count),
        .button_pressed(button_pressed),
        .lane_active(lane_active),
        .lane_value(lane_value),
        .hit_pulse(hit_pulse),
        .led_on(led_on)
    );

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, tb_reaction_time_fsm);
    end

    task tick;
        begin
            #5 clk = 1;
            #1;
            clk = 0;
            #4;
        end
    endtask

    initial begin
        reset = 1; beat_tick = 0; spawn = 0; button_pressed = 0; start_count = 3;
        tick;
        reset = 0;
        if (lane_active !== 0) $fatal(1, "lane did not reset to idle");

        // Check that pressing an empty lane does nothing.
        button_pressed = 1;
        #1;
        if (hit_pulse !== 0) $fatal(1, "blank-lane press incorrectly scored");
        tick;
        if (lane_active !== 0) $fatal(1, "blank-lane press activated the lane");
        button_pressed = 0;
        tick;

        // Start a note with value 3.
        spawn = 1;
        tick;
        spawn = 0;
        if (lane_active !== 1 || lane_value !== 3) $fatal(1, "spawn failed");

        beat_tick = 1;
        tick;
        beat_tick = 0;
        if (lane_value !== 2) $fatal(1, "countdown failed");

        // Check that an early press loses the note without scoring.
        button_pressed = 1;
        #1;
        if (hit_pulse !== 0) $fatal(1, "early press incorrectly scored");
        tick;
        if (lane_active !== 0) $fatal(1, "early press did not forfeit note");

        // Hold the button while the next note reaches zero.
        // Check that holding the button does not score again.
        start_count = 1;
        spawn = 1;
        tick;
        spawn = 0;
        beat_tick = 1;
        tick;
        beat_tick = 0;
        if (lane_value !== 0 || hit_pulse !== 0)
            $fatal(1, "held key incorrectly scored a later note");
        beat_tick = 1;
        tick;
        beat_tick = 0;
        if (lane_active !== 0) $fatal(1, "missed note did not expire");

        button_pressed = 0;
        tick;

        // Start a value 1 note and move it to the hit time.
        start_count = 1;
        spawn = 1;
        tick;
        spawn = 0;
        beat_tick = 1;
        tick;
        beat_tick = 0;
        if (lane_value !== 0 || lane_active !== 1) $fatal(1, "hit window was not reached");

        // Check that a new press sends a hit pulse.
        button_pressed = 1;
        #1;
        if (hit_pulse !== 1) $fatal(1, "correct press did not create hit pulse");
        tick;
        if (lane_active !== 0) $fatal(1, "hit note did not clear");
        if (led_on !== 1) $fatal(1, "hit LED did not turn on");

        button_pressed = 0;
        repeat (5) tick;
        if (led_on !== 0) $fatal(1, "hit LED stayed on too long");

        $display("ALL TESTS PASSED: tb_reaction_time_fsm");
        $finish;
    end
endmodule
