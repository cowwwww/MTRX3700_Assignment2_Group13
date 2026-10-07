module reaction_time_fsm #(
    parameter CLKS_PER_MS = 50000,
    parameter LED_FLASH_MS = 300
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       beat_tick,
    input  logic       spawn,
    input  logic [3:0] start_count,
    input  logic       button_pressed,
    output logic       lane_active,
    output logic [3:0] lane_value,
    output logic       hit_pulse,
    output logic       led_on
);

    // Positive edge detection from the Reaction Time Game lesson.
    logic button_q0;
    logic button_edge;

    always_ff @(posedge clk) begin
        if (reset)
            button_q0 <= 1'b0;
        else
            button_q0 <= button_pressed;
    end

    assign button_edge = button_pressed & ~button_q0;

    // One lane has three states.
    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        COUNTDOWN  = 2'b01,
        HIT_WINDOW = 2'b10
    } state_type;
    state_type current_state, next_state;

    // Next state logic.
    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (spawn)
                    next_state = COUNTDOWN;
            end

            COUNTDOWN: begin
                // Pressing early forfeits the note.
                if (button_edge)
                    next_state = IDLE;
                else if (beat_tick && lane_value == 4'd1)
                    next_state = HIT_WINDOW;
            end

            HIT_WINDOW: begin
                // A correct press scores. No press means the note expires next beat.
                if (button_edge)
                    next_state = IDLE;
                else if (beat_tick)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State and countdown registers.
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= IDLE;
            lane_value <= 4'd0;
        end
        else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (spawn)
                        lane_value <= start_count;
                    else
                        lane_value <= 4'd0;
                end

                COUNTDOWN: begin
                    if (button_edge)
                        lane_value <= 4'd0;
                    else if (beat_tick && lane_value > 0)
                        lane_value <= lane_value - 1'b1;
                end

                HIT_WINDOW: begin
                    if (button_edge || beat_tick)
                        lane_value <= 4'd0;
                end

                default: begin
                    lane_value <= 4'd0;
                end
            endcase
        end
    end

    assign lane_active = (current_state != IDLE);
    // A2: closing beat is excluded from this half-open hit window.
    assign hit_pulse = (current_state == HIT_WINDOW) && button_edge && !beat_tick;

    // Keep the hit LED on for about 300 ms.
    localparam LED_FLASH_CLKS = CLKS_PER_MS * LED_FLASH_MS;
    localparam LED_COUNT_WIDTH = (LED_FLASH_CLKS <= 1) ? 1 : $clog2(LED_FLASH_CLKS + 1);
    logic [LED_COUNT_WIDTH-1:0] led_count;

    always_ff @(posedge clk) begin
        if (reset) begin
            led_count <= 0;
        end
        else if (hit_pulse) begin
            led_count <= LED_FLASH_CLKS;
        end
        else if (led_count > 0) begin
            led_count <= led_count - 1'b1;
        end
    end

    assign led_on = (led_count > 0);

endmodule
