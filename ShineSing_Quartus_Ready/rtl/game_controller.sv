module game_controller (
    input  logic        clk,
    input  logic        reset,
    input  logic        beat_tick,
    input  logic [10:0] random_value,
    input  logic [3:0]  lane_active,
    input  logic [3:0]  hit_pulse,
    output logic [3:0]  spawn,
    output logic [3:0]  start_count,
    output logic [6:0]  score
);

    logic beat_phase;
    logic [1:0] lane_select;
    logic [6:0] hit_count;

    // Count how many lanes were hit on the same clock cycle.
    always_comb begin
        hit_count = {6'b0, hit_pulse[0]} +
                    {6'b0, hit_pulse[1]} +
                    {6'b0, hit_pulse[2]} +
                    {6'b0, hit_pulse[3]};
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            beat_phase <= 1'b0;
            lane_select <= 2'd0;
            spawn <= 4'b0000;
            start_count <= 4'd2;
            score <= 7'd0;
        end
        else begin
            // Spawn is a one clock pulse.
            spawn <= 4'b0000;

            // One new note every two beats.
            if (beat_tick) begin
                beat_phase <= ~beat_phase;

                if (beat_phase) begin
                    start_count <= 4'd2 + random_value[1:0];

                    if (!lane_active[lane_select])
                        spawn[lane_select] <= 1'b1;

                    lane_select <= lane_select + 1'b1;
                end
            end

            // Score saturates at 99.
            if (hit_count != 0) begin
                if (score + hit_count >= 7'd99)
                    score <= 7'd99;
                else
                    score <= score + hit_count;
            end
        end
    end

endmodule
