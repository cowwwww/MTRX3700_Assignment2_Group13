`timescale 1ns/1ps
// tb_classifier: templates from templates_test.hex (4 classes x 4 templates x D=8, made by
// make_test_templates.py); frames near each template are classified, an ambiguous one is rejected,
// the vote smooths a single wrong frame, and the gate clears the vote.
module tb_classifier;
    localparam int D = 8, FW = 16, NCLASS = 4, NT = 4, M = 5;
    logic clk = 0; always #10 clk = ~clk;
    logic reset = 1, enable = 1, feature_valid = 0; logic [D-1:0][FW-1:0] feature;
    logic [1:0] result; logic [7:0] confidence; logic reject, result_valid;
    classifier #(.D(D), .FW(FW), .NCLASS(NCLASS), .NT(NT), .M(M), .RHO_NUM(9), .RHO_DEN(10)) dut (.*);
    logic [D-1:0][FW-1:0] templ [0:NCLASS*NT-1];
    initial $readmemh("templates_test.hex", templ);
    int errors = 0;
    task automatic frame(input logic [D-1:0][FW-1:0] f);
        @(negedge clk); feature = f; feature_valid = 1; @(negedge clk); feature_valid = 0;
        wait (result_valid); @(negedge clk);
    endtask
    function automatic logic [D-1:0][FW-1:0] near(input int t, input int delta);
        logic [D-1:0][FW-1:0] f; f = templ[t];
        for (int i = 0; i < D; i++) f[i] = f[i] + FW'(delta);
        return f;
    endfunction
    initial begin
        `ifdef VERILATOR $dumpfile("waveform.fst"); `else $dumpfile("waveform.vcd"); `endif
        $dumpvars();
        repeat (3) @(posedge clk); reset = 0;
        // each class: 3 frames near one of its templates -> result follows, not rejected
        for (int c = 0; c < NCLASS; c++) begin
            repeat (3) frame(near(c * NT + 1, 7));
            if (result != c || reject) begin errors++; $display("FAIL: class %0d frames -> class %0d reject=%0d", c, result, reject); end
        end
        $display("class 3 confidence = %0d", confidence);
        // a single wrong frame does not flip the vote (4 votes for 3, 1 for 0)
        frame(near(0 * NT + 2, 3));
        if (result != 3) begin errors++; $display("FAIL: one stray frame flipped the vote to %0d", result); end
        // a frame midway between two classes is rejected
        begin logic [D-1:0][FW-1:0] mid; for (int i = 0; i < D; i++) mid[i] = (templ[0][i] + templ[NT][i]) / 2;   // between class 0 and class 1
              frame(mid); $display("midway: d1=%0d d2=%0d reject=%0d", dut.d1, dut.d2, reject);
              if (!reject) begin errors++; $display("FAIL: midway frame was not rejected"); end end
        // gate closed: the vote is forgotten
        enable = 0; frame(near(1 * NT, 0)); enable = 1;
        frame(near(2 * NT, 0));
        if (result != 2) begin errors++; $display("FAIL: after the gate closed, first frame of class 2 gave %0d", result); end
        if (errors == 0) $display("PASS: classifier nearest-template + vote + reject + gate behave");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
