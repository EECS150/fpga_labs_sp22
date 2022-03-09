`timescale 1ns/100ps

`define SECOND 1000000000
`define MS 1000000
`define CLK_PERIOD 8
`define B_SAMPLE_CNT_MAX 5
`define B_PULSE_CNT_MAX 5

`define CLOCK_FREQ 125_000_000
`define BAUD_RATE 115_200
// Number of cycles to send one character using the UART
`define CYCLES_PER_CHAR ((`CLOCK_FREQ / `BAUD_RATE) * 10)
// Make this a little longer than the time to send a character over UART so
// the FIFO will buffer UART characters
`define CYCLES_PER_SECOND (`CYCLES_PER_CHAR * 6)

module system_tb();
    reg clk = 0;
    wire audio_pwm;
    wire [5:0] leds;
    reg [2:0] buttons;
    reg [1:0] switches;
    reg rst;
    reg [7:0] data_in;
    reg data_in_valid;
    wire data_in_ready;

    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;

    // Generate system clock
    always #(`CLK_PERIOD/2) clk <= ~clk;

    z1top #(
        .B_SAMPLE_CNT_MAX(`B_SAMPLE_CNT_MAX),
        .B_PULSE_CNT_MAX(`B_PULSE_CNT_MAX),
        .CLOCK_FREQ(`CLOCK_FREQ),
        .BAUD_RATE(`BAUD_RATE),
        .CYCLES_PER_SECOND(`CYCLES_PER_SECOND)
    ) top (
        .CLK_125MHZ_FPGA(clk),
        .BUTTONS({buttons, rst}),
        .SWITCHES(switches),
        .LEDS(leds),
        .AUD_PWM(audio_pwm),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX)
    );

    // Instantiate an off-chip UART here that uses the RX and TX lines
    // You can refer to the echo_testbench from lab 4
    uart #(
        .BAUD_RATE(`BAUD_RATE),
        .CLOCK_FREQ(`CLOCK_FREQ)
    ) off_chip_uart (
        .clk(clk),
        .reset(rst),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .data_out(),
        .data_out_valid(),
        .data_out_ready(1'b0),
        .serial_in(FPGA_SERIAL_TX),
        .serial_out(FPGA_SERIAL_RX)
    );

    task ua_send;
        input [7:0] data;
        begin
            while (!data_in_ready) begin
                @(posedge clk);
            end
            #1;
            data_in_valid = 'b1;
            data_in = data;
            @(posedge clk); #1;
            data_in_valid = 'b0;
        end
    endtask

    initial begin
        `ifndef IVERILOG
            $vcdpluson;
        `endif
        `ifdef IVERILOG
            $dumpfile("system_tb.fst");
            $dumpvars(0, system_tb);
        `endif
        data_in = 8'd0;
        data_in_valid = 1'b0;
        buttons = 0;
        switches = 0;
        // Simulate pushing the reset button and holding it for a while
        rst = 1'b0;
        repeat (5) @(posedge clk); #1;
        rst = 1'b1;
        repeat (40) @(posedge clk); #1;
        rst = 1'b0;

        // Send characters through the off_chip_uart
        fork
            // Host -> FPGA sending thread
            begin
                ua_send("z");
                ua_send("x");
                ua_send("c");
            end
            // FPGA checking thread
            begin
                // Initially the fcw should be 0
                // assert(top.nco.fcw == 0);

                // It takes `CYCLES_PER_CHAR cycles for the UART to send the
                // FPGA one character
                repeat (`CYCLES_PER_CHAR) @(posedge clk);

                // Wait a few more cycles for the piano to fetch the character
                // from the RX FIFO
                repeat (10) @(posedge clk);

                // Check the FCW is what you expect
                // assert(top.nco.fcw == WHAT YOU EXPECT)

                // Wait for the next note to begin playing
                // recall note_length = 1/5th of a second by default
                repeat (`CYCLES_PER_SECOND / 5 + 10) @(posedge clk);

                // Check the FCW is what you expect
                // assert(top.nco.fcw == WHAT YOU EXPECT)

                // TODO: add more stimulus and assertions, adjust note_length
            end
        join
        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end

    initial begin
        repeat (`CYCLES_PER_CHAR + `CYCLES_PER_SECOND * 4) @(posedge clk);
        $error("Timing out");
        $fatal();
    end
endmodule
