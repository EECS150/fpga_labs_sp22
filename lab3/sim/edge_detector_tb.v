`timescale 1ns/1ns

`define CLK_PERIOD 8
`define EDGE_DETECTOR_WIDTH 2

module edge_detector_tb();
    // Generate 125 MHz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O of edge detector
    reg [`EDGE_DETECTOR_WIDTH-1:0] signal_in;
    wire [`EDGE_DETECTOR_WIDTH-1:0] edge_detect_pulse;

    edge_detector #(
        .WIDTH(`EDGE_DETECTOR_WIDTH)
    ) DUT (
        .clk(clk),
        .signal_in(signal_in),
        .edge_detect_pulse(edge_detect_pulse)
    );

    reg done = 0;
    reg [31:0] tests_failed = 0;

    initial begin
        `ifdef IVERILOG
            $dumpfile("edge_detector_tb.fst");
            $dumpvars(0, edge_detector_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        fork
            // Stimulus thread
            begin
                signal_in = 2'b00;
                repeat (2) @(posedge clk); #1;
                signal_in = 2'b01;
                repeat (5) @(posedge clk); #1;
                signal_in = 2'b00;
                repeat (5) @(posedge clk); #1;
                signal_in = 2'b10;
                repeat (3) @(posedge clk); #1;
                signal_in = 2'b00;
                repeat (10) @(posedge clk); #1;
                if (!done) begin
                    $error("Testbench timeout");
                    $fatal();
                end
                else begin
                    $display("Testbench finished, errors: %d", tests_failed);
                end
            end
            // Output checker thread
            begin
                // Wait for the rising edge of the edge detector output
                @(posedge edge_detect_pulse[0]);

                // Let 1 clock cycle elapse
                @(posedge clk); #1;

                // Check that the edge detector output is now low
                if (edge_detect_pulse[0] !== 1'b0) begin
                    $error("Failure 1: Your edge detector's output wasn't 1 clock cycle wide");
                    tests_failed = tests_failed + 1;
                end

                // Wait for the 2nd rising edge, and same logic, but for the second bit
                @(posedge edge_detect_pulse[1]);
                @(posedge clk); #1;
                if (edge_detect_pulse[1] !== 1'b0) begin
                    $error("Failure 2: Your edge detector's output wasn't 1 clock cycle wide");
                    tests_failed = tests_failed + 1;
                end
                done = 1;
            end
        join

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end

    always @(posedge edge_detect_pulse[0] or posedge edge_detect_pulse[1]) begin
        $display("DEBUG: Detected rising edge at time %d", $time);
    end
endmodule
