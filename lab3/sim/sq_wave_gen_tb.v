`timescale 1ns/1ns
`define CLK_PERIOD 8

module sq_wave_gen_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O
    wire [9:0] code;
    reg next_sample;

    sq_wave_gen DUT (
        .clk(clk),
        .code(code),
        .next_sample(next_sample)
    );

    integer code_file;
    integer next_sample_fetch;
    initial begin
        `ifdef IVERILOG
            $dumpfile("sq_wave_gen_tb.fst");
            $dumpvars(0, sq_wave_gen_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        code_file = $fopen("codes.txt", "w");

        next_sample = 0;
        @(posedge clk); #1;

        repeat (122000) begin
            // Pull next_sample every X cycles where X is a random number in [2, 9]
            next_sample_fetch = ($urandom() % 8) + 2;
            repeat (next_sample_fetch) @(posedge clk);
            #1;
            next_sample = 1;
            @(posedge clk); #1;
            $fwrite(code_file, "%d\n", code);
            next_sample = 0;
            @(posedge clk); #1;
        end
        $fclose(code_file);

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
