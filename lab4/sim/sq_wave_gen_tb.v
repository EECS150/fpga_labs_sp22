`timescale 1ns/1ns
`define CLK_PERIOD 8

module sq_wave_gen_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O
    wire [9:0] code;
    reg [2:0] buttons;
    wire [3:0] leds;
    reg next_sample;
    reg rst;

    sq_wave_gen DUT (
        .clk(clk),
        .rst(rst),
        .code(code),
        .next_sample(next_sample),
        .buttons(buttons),
        .leds(leds)
    );

    integer code_file;
    integer next_sample_fetch;
    integer num_samples_fetched = 0;
    initial begin
        `ifdef IVERILOG
            $dumpfile("sq_wave_gen_tb.fst");
            $dumpvars(0, sq_wave_gen_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        code_file = $fopen("codes.txt", "w");
        rst = 1;
        next_sample = 0;
        @(posedge clk); #1;
        rst = 0;

        @(posedge clk); #1;

        fork
            begin
                repeat (122000) begin
                    // Pull next_sample every X cycles where X is a random number in [2, 9]
                    next_sample_fetch = ($urandom() % 8) + 2;
                    repeat (next_sample_fetch) @(posedge clk);
                    #1;
                    next_sample = 1;
                    @(posedge clk); #1;
                    $fwrite(code_file, "%d\n", code);
                    num_samples_fetched = num_samples_fetched + 1;
                    next_sample = 0;
                    @(posedge clk); #1;
                end
            end
            begin
                // TODO: play with the buttons to adjust the output frequency
                // hint: use the num_samples_fetched integer to wait for
                // X samples to be fetched by the sampling thread, example below
                @(num_samples_fetched == 500);
                $display("Fetched 500 samples at time %t", $time);
                @(num_samples_fetched == 5000);
                $display("Fetched 5000 samples at time %t", $time);
            end
        join

        $fclose(code_file);

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
