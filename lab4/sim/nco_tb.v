`timescale 1ns/1ns
`define CLK_PERIOD 8

module nco_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O
    reg [23:0] fcw;
    reg rst;
    reg next_sample;
    wire [9:0] code;

    nco DUT (
        .clk(clk),
        .rst(rst),
        .fcw(fcw),
        .next_sample(next_sample),
        .code(code)
    );

    integer code_file;
    integer next_sample_fetch;
    integer num_samples_fetched = 0;
    initial begin
        `ifdef IVERILOG
            $dumpfile("nco_tb.fst");
            $dumpvars(0, nco_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        code_file = $fopen("nco_codes.txt", "w");
        rst = 1;
        next_sample = 0;
        @(posedge clk); #1;
        rst = 0;

        fork
            // Thread to pull samples from the NCO
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
            // Thread for you to drive fcw
            begin
                // the fcw is 24 bits, with the 8 MSB used to index into the sine LUT
                // if we set fcw = 2^16, the NCO should index into LUT
                // addresses 0, 1, 2, 3, ... for every next_sample
                fcw = 'h10000;
                @(num_samples_fetched == 20);

                // TODO: play with the fcw to adjust the output frequency
                // hint: use the num_samples_fetched integer to wait for
                // X samples to be fetched by the sampling thread
                fcw = 0; // TODO: change this to play a 440 Hz tone
            end
            // Thread to check code for fcw = 2^16
            begin
                // Initially the code comes from address 0 of the LUT
                assert(code == 10'b1000000000) else $error("Code on reset should be LUT[0]");
                @(num_samples_fetched == 1);
                assert(code == 10'b1000001100) else $error("Code after 1 sample should be LUT[1]");
                @(num_samples_fetched == 2);
                assert(code == 10'b1000011001) else $error("Code after 2 samples should be LUT[2]");
                @(num_samples_fetched == 10);
                assert(code == 10'b1001111100) else $error("Code after 10 samples should be LUT[10]");
            end
        join

        $fclose(code_file);

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
