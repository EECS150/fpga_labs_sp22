module z1top #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200,
    /* verilator lint_off REALCVT */
    // Sample the button signal every 500us
    parameter integer B_SAMPLE_CNT_MAX = 0.0005 * CLOCK_FREQ,
    // The button is considered 'pressed' after 100ms of continuous pressing
    parameter integer B_PULSE_CNT_MAX = 0.100 / 0.0005
    /* lint_on */
)(
    input CLK_125MHZ_FPGA,
    input [3:0] BUTTONS,
    input [1:0] SWITCHES,
    output [5:0] LEDS,
    output AUD_PWM,
    output AUD_SD,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);
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
    assign AUD_PWM = 1'b0;
    assign AUD_SD = 1'b0;

    wire rst;
    assign rst = buttons_pressed[0];

    reg [7:0] data_in;
    wire [7:0] data_out;
    wire data_in_valid, data_in_ready, data_out_valid, data_out_ready;

    // This UART is on the FPGA and communicates with your desktop
    // using the FPGA_SERIAL_TX, and FPGA_SERIAL_RX signals. The ready/valid
    // interface for this UART is used on the FPGA design.
    uart # (
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) on_chip_uart (
        .clk(CLK_125MHZ_FPGA),
        .reset(rst),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .serial_in(FPGA_SERIAL_RX),
        .serial_out(FPGA_SERIAL_TX)
    );

    // This is a small state machine that will pull a character from the uart_receiver
    // over the ready/valid interface, modify that character, and send the character
    // to the uart_transmitter, which will send it over the serial line.

    // If a ASCII letter is received, its case will be reversed and sent back. Any other
    // ASCII characters will be echoed back without any modification.
    reg has_char;
    reg [7:0] char;

    always @(posedge CLK_125MHZ_FPGA) begin
        if (rst) has_char <= 1'b0;
        else has_char <= has_char ? !data_in_ready : data_out_valid;
    end

    always @(posedge CLK_125MHZ_FPGA) begin
        if (!has_char) char <= data_out;
    end

    always @ (*) begin
        if (char >= 8'd65 && char <= 8'd90) data_in = char + 8'd32;
        else if (char >= 8'd97 && char <= 8'd122) data_in = char - 8'd32;
        else data_in = char;
    end

    assign data_in_valid = has_char;
    assign data_out_ready = !has_char;
endmodule
