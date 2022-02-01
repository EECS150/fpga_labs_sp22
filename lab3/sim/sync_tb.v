`timescale 1ns/1ns
`define CLK_PERIOD 8

// This testbench checks that your synchronizer is made up of 2 flip-flops serially connected.
// This testbench cannot model metastability.

module sync_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O of synchronizer
    reg async_signal;
    wire sync_signal;

    synchronizer #(.WIDTH(1)) DUT (
        .clk(clk),
        .async_signal(async_signal),
        .sync_signal(sync_signal)
    );

    initial begin
        `ifdef IVERILOG
            $dumpfile("sync_tb.fst");
            $dumpvars(0, sync_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        // We use fork-join to create 2 threads that operate in parallel
        fork
            // This first thread will send a test signal into the DUT's async_signal input
            begin
                async_signal = 1'b0;
                #(`CLK_PERIOD * 2) async_signal = 1'b1;
                #(`CLK_PERIOD * 1) async_signal = 1'b0;
                #(`CLK_PERIOD * 3) async_signal = 1'b1;
                #(`CLK_PERIOD * 2) async_signal = 1'b0;
                #(`CLK_PERIOD * 4) async_signal = 1'b1;
            end

            // This second thread will monitor the DUT's sync_signal output for the correct response
            // The #1 is a Verilog oddity that's needed since the sync_signal changes after the rising edge of the clock,
            //   not at the same instant as the rising edge.
            begin
                repeat (4) @(posedge clk); #1 if (sync_signal !== 1'b1) $error("Check 1 failed");
                repeat (1) @(posedge clk); #1 if (sync_signal !== 1'b0) $error("Check 2 failed");
                repeat (3) @(posedge clk); #1 if (sync_signal !== 1'b1) $error("Check 3 failed");
                repeat (2) @(posedge clk); #1 if (sync_signal !== 1'b0) $error("Check 4 failed");
                repeat (4) @(posedge clk); #1 if (sync_signal !== 1'b1) $error("Check 5 failed");
            end
        join

        repeat (3) @(posedge clk);  // Wait for a little time and perform the final check again
        if (sync_signal !== 1'b1) $error("Check 6 failed");

        $display("Test finished");

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
