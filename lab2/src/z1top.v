// Comment out this line when you want to instantiate your counter
`define ADDER_CIRCUIT

module z1top (
    input CLK_125MHZ_FPGA,
    input [3:0] BUTTONS,
    input [1:0] SWITCHES,
    output [5:0] LEDS
);

`ifdef ADDER_CIRCUIT
    wire [14:0] adder_out;
    structural_adder user_adder (
        .a({11'b0,SWITCHES[0],BUTTONS[1:0]}),
        .b({11'b0,SWITCHES[1],BUTTONS[3:2]}),
        .sum(adder_out)
    );
    assign LEDS[3:0] = adder_out[3:0]; // truncate upper bits

    // Self test of the structural adder
    wire [13:0] adder_operand1, adder_operand2;
    wire [14:0] structural_out, behavioral_out;
    wire test_fail;
    assign LEDS[4] = ~test_fail;
    assign LEDS[5] = ~test_fail;

    structural_adder structural_test_adder (
        .a(adder_operand1),
        .b(adder_operand2),
        .sum(structural_out)
    );

    behavioral_adder behavioral_test_adder (
        .a(adder_operand1),
        .b(adder_operand2),
        .sum(behavioral_out)
    );

    adder_tester tester (
        .adder_operand1(adder_operand1),
        .adder_operand2(adder_operand2),
        .structural_sum(structural_out),
        .behavioral_sum(behavioral_out),
        .clk(CLK_125MHZ_FPGA),
        .test_fail(test_fail)
    );
`else
    assign LEDS[5:4] = 0;

    counter ctr (
        .clk(CLK_125MHZ_FPGA),
        .ce(SWITCHES[0]),
        .LEDS(LEDS[3:0])
    );
`endif
endmodule
