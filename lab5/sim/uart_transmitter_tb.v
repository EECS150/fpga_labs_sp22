`timescale 1ns/1ps

// UART_Transmitter is essentially a reverse of UART_Receiver
module uart_transmitter_tb();
  localparam CLOCK_FREQ   = 125_000_000;
  localparam CLOCK_PERIOD = 1_000_000_000 / CLOCK_FREQ;
  localparam BAUD_RATE    = 115_200;
  localparam integer BAUD_PERIOD  = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

  localparam CHAR0 = 8'h61; // ~ 'a'
  localparam NUM_CHARS = 16;

  localparam INPUT_DELAY = 1000;

  reg clk, rst;
  initial clk = 0;
  always #(CLOCK_PERIOD / 2) clk = ~clk;

  // producer (testbench) --> (data_in R/V) uart_transmitter (serial_out) --> host

  wire [7:0] data_in;
  reg data_in_valid;
  wire data_in_ready;
  wire serial_out;

  uart_transmitter #(
    .CLOCK_FREQ(CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) DUT (
    .clk(clk),
    .reset(rst),

    .data_in(data_in),             // input
    .data_in_valid(data_in_valid), // input
    .data_in_ready(data_in_ready), // output
    .serial_out(serial_out)        // output
  );

  integer i, j, c;

  // this holds characters sent by the UART_transmitter to the host via serial line
  // including the start and stop bits
  reg [10-1:0] chars_to_host [NUM_CHARS-1:0];
  // this holds characters received from data_in via the Handshake interface
  reg [7:0] chars_from_data_in [NUM_CHARS-1:0];

  // initialize test vectors
  initial begin
    #0;
    for (c = 0; c < NUM_CHARS; c = c + 1) begin
      chars_from_data_in[c] = CHAR0 + c;
    end
  end

  reg [31:0] cnt;

  assign data_in = chars_from_data_in[cnt];
  reg data_in_fired;

  always @(posedge clk) begin
    if (rst) begin
      cnt <= 0;
    end
    else begin
      if (data_in_fired === 1'b1) begin
        data_in_fired <= 1'b0;
        if (data_in_ready === 1'b1) begin
          $error("[time %t] Failed: data_in_ready should go LOW in the next clock edge after firing data_in\n", $time);
          //$fatal();
        end
      end
      else if (data_in_valid === 1'b1 && data_in_ready === 1'b1) begin
        data_in_fired <= 1'b1;
        cnt <= cnt + 1;
        $display("[time %t] [data_in] Sent char: 8'h%h (=%s)", $time, data_in, data_in);
      end
    end
  end

  initial begin
    data_in_valid = 1'b0;

    repeat (10) @(posedge clk);

    // This for-loop emulates the producer
    // It sends new character (data_in) to the uart_transmitter via the
    // handshake interface as long as the uart_transmitter is ready
    for (j = 0; j < NUM_CHARS; j = j + 1) begin
      // wait until uart_transmitter is ready to get new character
      wait (data_in_ready === 1'b1);

      // Add some delay between successive characters sent to uart
      #(INPUT_DELAY);

      // the producer has valid data
      @(negedge clk);
      data_in_valid = 1'b1;

      // the uart_transmitter should have received the character at this posedge clk
      // since valid and ready are both HIGH
      // @(posedge clk);

      @(negedge clk);
      data_in_valid = 1'b0; // pull valid LOW to make life harder

    end
  end

  integer num_mismatches = 0;

  initial begin
    #0;
    `ifdef IVERILOG
        $dumpfile("uart_transmitter_tb.fst");
        $dumpvars(0, uart_transmitter_tb);
    `endif
    `ifndef IVERILOG
        $vcdpluson;
    `endif

    rst = 1'b1;
    cnt = 0;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 1'b0;

    if (data_in_ready === 1'b0) begin
      $error("[time %t] Failed: data_in_ready should not be LOW after reset", $time);
      repeat (5) @(posedge clk);
      $fatal();
    end

    if (serial_out !== 1) begin
      $error("[time %t] Failed: serial_out should stay HIGH if there is no data_in to receive by handshake!", $time);
      repeat (5) @(posedge clk);
      $fatal();
    end

    // Delay for some time
    repeat (100) @(posedge clk);

    // This for-loop checks the output of the serial interface
    // to ensure that the serialized output bits match the characters sent
    // by the producer (through the uart_transmitter)
    for (c = 0; c < NUM_CHARS; c = c + 1) begin
      // Wait until serial_out is LOW (start of transaction)
      wait (serial_out === 1'b0);

      for (i = 0; i < 10; i = i + 1) begin
        // sample output half-way through the baud period to avoid tricky edge cases
        #(BAUD_PERIOD / 2);
        chars_to_host[c][i] = serial_out;
        #(BAUD_PERIOD / 2);
      end
      $display("[time %t] [serial_out] Got char: start_bit=%b, payload=8'h%h (=%s), stop_bit=%b",
               $time,
               chars_to_host[c][0],
               chars_to_host[c][8:1], chars_to_host[c][8:1],
               chars_to_host[c][9]);
    end

    // Delay for some time
    repeat (10) @(posedge clk);

    // Check results
    for (c = 0; c < NUM_CHARS; c = c + 1) begin
      if (chars_from_data_in[c] !== chars_to_host[c][8:1]) begin
        $error("Mismatches at char %d: char_to_host=%h (=%s), char_from_data_in=%h (=%s)",
                 c,
                 chars_to_host[c][8:1], chars_to_host[c][8:1],
                 chars_from_data_in[c], chars_from_data_in[c]);
        num_mismatches = num_mismatches + 1;
      end

      if (chars_to_host[c][0] !== 0)
        $error("[char #%d] Failed: Start bit is expected to be LOW!", c);
      if (chars_to_host[c][9] !== 1)
        $error("[char #%d] Failed: End bit is expected to HIGH!", c);
    end

    if (serial_out !== 1) begin
      $error("[time %t] Failed: serial_out should stay HIGH if there is no data_in to receive by handshake!", $time);
      //$fatal();
    end

    if (num_mismatches > 0)
      $display("Tests failed!");
    else
      $display("Tests passed!");

    #100;
    $finish();
  end

  // Timeout check
  initial begin
    // Should not take more than the total time needed to send all characters plus
    // some extra spare time
    #((BAUD_PERIOD * 10 + INPUT_DELAY) * (NUM_CHARS) + 5000);
    $error("Timeout!");
    $fatal();
  end

endmodule
