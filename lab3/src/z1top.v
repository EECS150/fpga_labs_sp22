`define CLOCK_FREQ 125_000_000

module z1top (
    input CLK_125MHZ_FPGA,
    input [3:0] BUTTONS,
    input [1:0] SWITCHES,
    output [5:0] LEDS,
    output AUD_PWM,
    output AUD_SD
);
    assign LEDS[5:4] = 2'b11;

    // Button parser test circuit
    // Sample the button signal every 500us
    localparam integer B_SAMPLE_CNT_MAX = $rtoi(0.0005 * `CLOCK_FREQ);
    // The button is considered 'pressed' after 100ms of continuous pressing
    localparam integer B_PULSE_CNT_MAX = $rtoi(0.100 / 0.0005);

    wire [3:0] buttons_pressed;
    button_parser #(
        .WIDTH(4),
        .SAMPLE_CNT_MAX(B_SAMPLE_CNT_MAX),
        .PULSE_CNT_MAX(B_PULSE_CNT_MAX)
    ) bp (
        .clk(CLK_125MHZ_FPGA),
        .in(BUTTONS),
        .out(buttons_pressed)
    );

    counter count (
        .clk(CLK_125MHZ_FPGA),
        .ce(SWITCHES[0]),
        .buttons(buttons_pressed),
        .leds(LEDS[3:0])
    );

    assign AUD_SD = SWITCHES[1]; // 1 = audio enabled
    wire [9:0] code;
    wire next_sample;
    dac #(
        .CYCLES_PER_WINDOW(1024)
    ) dac (
        .clk(CLK_125MHZ_FPGA),
        .code(code),
        .next_sample(next_sample),
        .pwm(AUD_PWM)
    );

    sq_wave_gen gen (
        .clk(CLK_125MHZ_FPGA),
        .next_sample(next_sample),
        .code(code)
    );
endmodule
