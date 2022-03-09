`timescale 1ns/1ns

`define CLK_PERIOD 8

module fifo_tb();
  localparam WIDTH = 32;
  localparam LOGDEPTH = 3;
  localparam DEPTH = (1 << LOGDEPTH);

  reg clk = 0;
  reg rst = 0;

  always #(`CLK_PERIOD/2) clk <= ~clk;

  // Reg filled with test vectors for the testbench
  reg [WIDTH-1:0] test_values[50-1:0];
  // Reg used to collect the data read from the FIFO
  reg [WIDTH-1:0] received_values[50-1:0];

  // Enqueue signals (Write to FIFO)
  reg wr_en;
  reg [WIDTH-1:0] din;
  wire full;

  // Dequeue signals (Read from FIFO)
  wire empty;
  wire [WIDTH-1:0] dout;
  reg rd_en;

  fifo #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk(clk),
    .rst(rst),

    .wr_en(wr_en),  // input
    .din(din),      // input
    .full(full),    // output

    .empty(empty),  // output
    .dout(dout),    // output
    .rd_en(rd_en)   // input
  );

  // This could be a bit verbose
  /*
  always @(posedge clk) begin
    $display("At time %d, enq_valid=%d, enq_ready=%d, enq_data=%d, deq_valid=%d, deq_ready=%d, deq_data=%d, WRITE=%d, READ=%d",
      $time,
      enq_valid, enq_ready, enq_data,
      deq_valid, deq_ready, deq_data,
      (enq_valid && enq_ready ? enq_data : 32'dX),
      (deq_valid && deq_ready ? deq_data : 32'dX));
  end
  */

  // This task will push some data to the FIFO through the write interface
  // If violate_interface == 1'b1, we will force 'wr_en' high even if the FIFO indicates it is full
  // If violate_interface == 1'b0, we won't write if the FIFO indicates it is full
  task write_to_fifo;
    input [WIDTH-1:0] write_data;
    input violate_interface;
    begin
      #1;
      // If we want to not violate the interface agreement, if we are already full, don't write
      if (!violate_interface && full) begin
        wr_en = 1'b0;
      end
      // In all other cases, we will force a write
      else begin
        wr_en = 1'b1;
      end

      // Write should be performed when enq_ready and enq_valid are HIGH
      din = write_data;

      // Wait for the clock edge to perform the write
      @(posedge clk); #1;

      // Deassert write
      wr_en = 1'b0;
    end
  endtask

  // This task will read some data from the FIFO through the read interface
  // violate_interface does the same as for the write_to_fifo task
  task read_from_fifo;
    input violate_interface;
    output [WIDTH-1:0] read_data;
    begin
      #1;
      if (!violate_interface && empty) begin
        rd_en = 1'b0;
      end
      else begin
        rd_en = 1'b1;
      end

      // Deassert read
      @(posedge clk); #1;

      read_data = dout;
      rd_en = 1'b0;
    end
  endtask

  integer i;
  integer num_mismatches;
  integer num_items = 50;
  integer write_delay, read_delay;

  /* Signals used for the simultaneous read/write test */
  integer write_idx = 0;
  integer write_start = 0;
  integer read_idx = 0;
  integer read_start = 0;

  integer z;
  initial begin: TB
    `ifndef IVERILOG
        $vcdpluson;
        $vcdplusmemon;
    `endif
    `ifdef IVERILOG
        $dumpfile("fifo_tb.fst");
        $dumpvars(0, fifo_tb);
        for(z = 0; z < DEPTH; z = z + 1) begin
            // TODO: replace this line with a path to the 2D reg in your FIFO
            // to show each entry in the waveform
            // $dumpvars(0, dut.memory[z]);
        end
    `endif

    $display("This testbench was run with these params:");
    $display("CLK_PERIOD = %d, WIDTH = %d, DEPTH = %d", `CLK_PERIOD, WIDTH, DEPTH);

    // Generate data to write to the FIFO
    for (i = 0; i < 50; i = i + 1) begin
      test_values[i] <= i + 1000;
    end

    wr_en = 0;
    din = 0;
    rd_en = 0;

    rst = 1'b1;
    @(posedge clk); #1;
    rst = 1'b0;
    @(posedge clk); #1;

    // ==================== Basic tests ===================================
    // Let's begin with a simple complete write and read sequence to the FIFO

    // Check initial conditions, verify that the FIFO is not full, it is empty
    if (empty !== 1'b1) begin
      $error("Failure: After reset, the FIFO isn't empty. empty = %b", empty);
    end

    if (full !== 1'b0) begin
      $error("Failure: After reset, the FIFO is full. full = %b", full);
    end

    @(posedge clk);

    // Begin pushing data into the FIFO with a 1 cycle delay in between each write operation
    for (i = 0; i < DEPTH - 1; i = i + 1) begin
      write_to_fifo(test_values[i], 1'b0);

      // Perform checks on empty, full
      if (empty === 1'b1) begin
        $error("Failure: While being filled, FIFO said it was empty");
      end

      if (full === 1'b1) begin
        $error("Failure: While being filled, FIFO was full before all entries were written");
      end

      // Insert single-cycle delay between each write
      @(posedge clk);
    end

    // Perform the final write
    write_to_fifo(test_values[DEPTH-1], 1'b0);

    // Check that the FIFO is now full
    if (full !== 1'b1 || empty === 1'b1) begin
      $error("Failure: FIFO wasn't full or empty went high after writing all values. full = %b, empty = %b", full, empty);
    end

    // Cycle the clock, the FIFO should still be full!
    repeat (10) @(posedge clk);
    // The FIFO should still be full!
    if (full !== 1'b1 || empty === 1'b1) begin
      $error("Failure: Cycling the clock while the FIFO is full shouldn't change its state! full = %b, empty = %b", full, empty);
    end

    // Try stuffing the FIFO with more data while it's full (overflow protection check)
    repeat (20) begin
      write_to_fifo(0, 1'b1);
      // Check that the FIFO is still full, has the max num of entries, and isn't empty
      if (full !== 1'b1 || empty === 1'b1) begin
        $error("Failure: Overflowing the FIFO changed its state (your FIFO should have overflow protection) full = %b, empty = %b", full, empty);
      end
    end

    repeat (5) @(posedge clk);

    // Read from the FIFO one by one with a 1 cycle delay in between reads
    for (i = 0; i < DEPTH - 1; i = i + 1) begin
      read_from_fifo(1'b0, received_values[i]);

      // Perform checks on empty, full
      if (empty === 1'b1) begin
        $error("Failure: FIFO was empty as its being drained");
      end
      if (full === 1'b1) begin
        $error("Failure: FIFO was full as its being drained");
      end

      @(posedge clk);
    end

    // Perform the final read
    read_from_fifo(1'b0, received_values[DEPTH-1]);
    // Check that the FIFO is now empty
    if (full !== 1'b0 || empty !== 1'b1) begin
      $error("Failure: FIFO wasn't empty or full is high after the FIFO has been drained. full = %b, empty = %b", full, empty);
    end

    // Cycle the clock and perform the same checks
    repeat (10) @(posedge clk);
    if (full !== 1'b0 || empty !== 1'b1) begin
      $error("Failure: FIFO should be empty after it has been drained. full = %b, empty = %b", full, empty);
    end

    // Finally, let's check that the data we received from the FIFO equals the data that we wrote to it
    num_mismatches = 0;
    for (i = 0; i < DEPTH; i = i + 1) begin
      if (test_values[i] !== received_values[i]) begin
        $error("Failure: Data received from FIFO not equal to data written. Entry %d, got %d, expected %d", i, received_values[i], test_values[i]);
        num_mismatches = num_mismatches + 1;
      end
    end

    // Now attempt a read underflow
    repeat (10) read_from_fifo(1'b1, received_values[0]);
    // Nothing should change, perform the same checks on full and empty
    if (full !== 1'b0 || empty !== 1'b1) begin
      $error("Failure: Empty FIFO wasn't empty or full went high when trying to read. full = %b, empty = %b", full, empty);
    end

    repeat (10) @(posedge clk);
    if (num_mismatches > 0)
      $fatal();

    $display("All the basic tests passed!");

    // ==================== Harder tests ==================================
    // Begin pushing data into the FIFO in successive cycles
    for (i = 0; i < DEPTH; i = i + 1) begin
      write_to_fifo(test_values[i], 1'b0);
    end

    // Add some delay
    repeat (5) @(posedge clk);

    // Read from the FIFO in successive cycles
    for (i = 0; i < DEPTH; i = i + 1) begin
      read_from_fifo(1'b0, received_values[i]);
    end

    num_mismatches = 0;
    for (i = 0; i < DEPTH; i = i + 1) begin
      if (test_values[i] !== received_values[i]) begin
        $error("Failure: Data received from FIFO not equal to data written. Entry %d, got %d, expected %d", i, received_values[i], test_values[i]);
        num_mismatches = num_mismatches + 1;
      end
    end
    if (num_mismatches > 0)
      $fatal();

    repeat (10) @(posedge clk);
    assert(empty == 1'b1);

    // Write and Read from FIFO for some number of items concurrently
    // Test with different combinations of the following variables
    num_items   = 50; // number of items to be sent and received
    write_delay = 0; // number of cycles to the next write
    read_delay  = 0; // number of cycles to the next read
    fork
      begin
        write_start = 1;
        write_idx = 0;
        for (i = 0; i < num_items; i = i + 1) begin
          write_to_fifo(test_values[write_idx], 1'b0);
          repeat (write_delay) @(posedge clk);
          write_idx = write_idx + 1;
        end
        write_start = 0;
      end
      begin
        repeat((write_delay + 2)) @(posedge clk);
        read_start = 1;
        read_idx = 0;
        while (!empty) begin
          read_from_fifo(1'b0, received_values[read_idx]);
          repeat (read_delay) @(posedge clk);
          read_idx = read_idx + 1;
        end
        read_start = 0;
      end
    join

    repeat (10) @(posedge clk);

    num_mismatches = 0;
    for (i = 0; i < num_items; i = i + 1) begin
      if (test_values[i] !== received_values[i]) begin
        $error("Failure: Data received from FIFO not equal to data written. Entry %d, got %d, expected %d", i, received_values[i], test_values[i]);
        num_mismatches = num_mismatches + 1;
      end
    end
    if (num_mismatches > 0)
      $fatal();

    $display("All the hard tests passed!");
    $finish();
  end

endmodule
