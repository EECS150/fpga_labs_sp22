`timescale 1ns/1ns
`define CLK_PERIOD 8

module fsm_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O
    reg rst;
    reg [2:0] buttons;
    wire [23:0] fcw;
    wire [3:0] leds;
    wire [1:0] leds_state;

    fsm #(.CYCLES_PER_SECOND(125_000_000)) DUT (
        .clk(clk),
        .rst(rst),
        .buttons(buttons),
        .leds(leds),
        .leds_state(leds_state),
        .fcw(fcw)
    );

    initial begin
        `ifdef IVERILOG
            $dumpfile("fsm_tb.fst");
            $dumpvars(0, fsm_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        buttons = 0;

        // TODO: toggle the buttons
        // verify state transitions with the LEDs
        // verify fcw is being set properly by the FSM

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
