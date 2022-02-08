`define CLOCK_FREQ 125_000_000

module z1top (
    input CLK_125MHZ_FPGA,
    input [3:0] BUTTONS,
    input [1:0] SWITCHES,
    output [5:0] LEDS,
    output AUD_PWM,
    output AUD_SD
);
    // Button parser test circuit
    // Sample the button signal every 500us
    localparam integer B_SAMPLE_CNT_MAX = $rtoi(0.0005 * `CLOCK_FREQ);
    // The button is considered 'pressed' after 100ms of continuous pressing
    localparam integer B_PULSE_CNT_MAX = $rtoi(0.100 / 0.0005);

    wire [3:0] buttons_pressed;
    wire [2:0] buttons_sq_wave, buttons_fsm;
    button_parser #(
        .WIDTH(4),
        .SAMPLE_CNT_MAX(B_SAMPLE_CNT_MAX),
        .PULSE_CNT_MAX(B_PULSE_CNT_MAX)
    ) bp (
        .clk(CLK_125MHZ_FPGA),
        .in(BUTTONS),
        .out(buttons_pressed)
    );

    wire next_sample;
    wire [9:0] code, sq_wave_code, nco_code;
    wire [3:0] fsm_leds, sq_wave_leds;
    wire [2:0] fsm_buttons, sq_wave_buttons;
    wire [23:0] fcw;
    wire [1:0] addr;
    wire [23:0] d_in;
    wire wr_en;
    wire [1:0] switches_sync;
    wire rst;

    synchronizer #(.WIDTH(2)) switch_sync (.clk(CLK_125MHZ_FPGA), .async_signal(SWITCHES), .sync_signal(switches_sync));

    assign AUD_SD = switches_sync[1]; // 1 = audio enabled
    assign LEDS[3:0] = switches_sync[0] ? fsm_leds : sq_wave_leds;
    assign code = switches_sync[0] ? nco_code : sq_wave_code;
    assign rst = buttons_pressed[3];
    assign sq_wave_buttons = switches_sync[0] ? 3'b000 : buttons_pressed[2:0];
    assign fsm_buttons = switches_sync[0] ? buttons_pressed[2:0] : 3'b000;

    dac #(
        .CYCLES_PER_WINDOW(1024)
    ) dac (
        .clk(CLK_125MHZ_FPGA),
        .rst(rst),
        .code(code),
        .next_sample(next_sample),
        .pwm(AUD_PWM)
    );

    sq_wave_gen gen (
        .clk(CLK_125MHZ_FPGA),
        .rst(rst),
        .next_sample(next_sample),
        .buttons(sq_wave_buttons),
        .code(sq_wave_code),
        .leds(sq_wave_leds)
    );

    nco nco (
        .clk(CLK_125MHZ_FPGA),
        .rst(rst),
        .fcw(fcw),
        .next_sample(next_sample),
        .code(nco_code)
    );

    fsm fsm (
        .clk(CLK_125MHZ_FPGA),
        .rst(rst),
        .buttons(fsm_buttons),
        .leds(fsm_leds),
        .leds_state(LEDS[5:4]),
        .fcw(fcw)
    );
endmodule
