`timescale 1ns/1ps

module echo_tb();
  reg clk, rst;
  localparam CLOCK_FREQ   = 125_000_000;
  localparam CLOCK_PERIOD = 1_000_000_000 / CLOCK_FREQ;
  localparam BAUD_RATE    = 115_200;
  localparam BAUD_PERIOD  = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

  localparam integer SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;

  localparam CHAR0     = 8'h41; // ~ 'A'
  localparam NUM_CHARS = 60;

  initial clk = 0;
  always #(CLOCK_PERIOD / 2) clk = ~clk;

  // host --> (serial_in) z1top (serial_out) --> host (echoed)

  reg  serial_in;
  wire serial_out;

  z1top #(
    .CLOCK_FREQ(CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .B_SAMPLE_CNT_MAX(5),
    .B_PULSE_CNT_MAX(5)
  ) DUT (
    .CLK_125MHZ_FPGA(clk),
    .BUTTONS({3'b0, rst}),
    .SWITCHES(2'b0),
    .LEDS(),
    .AUD_PWM(),
    .AUD_SD(),
    .FPGA_SERIAL_RX(serial_in),
    .FPGA_SERIAL_TX(serial_out)
  );

  integer i, j, c, c1, c2;
  reg [31:0] cycle_cnt;
  integer num_mismatches = 0;

  // this holds characters sent by the host to the serial line
  reg [7:0] chars_from_host [NUM_CHARS-1:0];
  // this holds characters received by the host from the serial line
  reg [9:0] chars_to_host   [NUM_CHARS-1:0];

  // initialize test vectors
  initial begin
    #0;
    for (c = 0; c < NUM_CHARS; c = c + 1) begin
      chars_from_host[c] = CHAR0 + c;
    end
  end

  always @(posedge clk) begin
    if (rst === 1'b1)
      cycle_cnt <= 0;
    else
      cycle_cnt <= cycle_cnt + 1;
  end

  // Host off-chip UART --> FPGA on-chip UART (receiver)
  // The host (testbench) sends a character to the CPU via the serial line
  task host_to_fpga;
  begin
    #0;
    serial_in = 1;

    for (c1 = 0; c1 < NUM_CHARS; c1 = c1 + 1) begin
      // Start bit
      serial_in = 0;
      #(BAUD_PERIOD);
      // Data bits (payload)
      for (i = 0; i < 8; i = i + 1) begin
        serial_in = chars_from_host[c1][i];
        #(BAUD_PERIOD);
      end
      // Stop bit
      serial_in = 1;
      #(BAUD_PERIOD);

      $display("[time %t, sim. cycle %d] [Host (tb) --> FPGA_SERIAL_RX] Sent char 8'h%h (= %s)",
               $time, cycle_cnt, chars_from_host[c1], chars_from_host[c1]);
    end
  end
  endtask

  // Host off-chip UART <-- FPGA on-chip UART (transmitter)
  // The host (testbench) expects to receive a character from the CPU via the serial line (echoed)
  task fpga_to_host;
  begin
    for (c2 = 0; c2 < NUM_CHARS; c2 = c2 + 1) begin
      // Wait until serial_out is LOW (start of transaction)
      wait (serial_out === 1'b0);

      for (j = 0; j < 10; j = j + 1) begin
        #(BAUD_PERIOD / 2);
        chars_to_host[c2][j] = serial_out;
        #(BAUD_PERIOD / 2);
      end

      $display("[time %t, sim. cycle %d] [Host (tb) <-- FPGA_SERIAL_TX] Got char: start_bit=%b, payload=8'h%h (= %s), stop_bit=%b",
        $time, cycle_cnt,
        chars_to_host[c2][0],
        chars_to_host[c2][8:1], chars_to_host[c2][8:1],
        chars_to_host[c2][9]);
    end
  end
  endtask

  task case_inverter;
    input [7:0]  in_char;
    output [7:0] out_char;
    begin
      if (in_char >= "a" && in_char <= "z")
        out_char = in_char - 8'd32;
      else if (in_char >= "A" && in_char <= "Z")
        out_char = in_char + 8'd32;
      else
        out_char = in_char;
    end
  endtask

  reg [7:0] cinv_char_to_host;

  initial begin
    #0;
    `ifdef IVERILOG
        $dumpfile("echo_tb.fst");
        $dumpvars(0, echo_tb);
    `endif
    `ifndef IVERILOG
        $vcdpluson;
    `endif

    rst = 1'b1;

    // Hold reset for a while
    repeat (40) @(posedge clk);

    rst = 1'b0;

    // Delay for some time
    repeat (10) @(posedge clk);

    // Launch the tasks in parallel
    fork
      begin
        host_to_fpga();
      end
      begin
        fpga_to_host();
      end
    join

    // Check results
    for (c = 0; c < NUM_CHARS; c = c + 1) begin
      case_inverter(chars_to_host[c][8:1], cinv_char_to_host);
      if (chars_from_host[c] !== cinv_char_to_host) begin
        $error("Mismatches at char %d: char_from_host=%h (= %s), char_to_host=%h (= %s)",
          c, chars_from_host[c], chars_from_host[c],
          cinv_char_to_host, cinv_char_to_host);
          num_mismatches = num_mismatches + 1;
      end
    end

    if (num_mismatches > 0)
      $display("Tests failed");
    else
      $display("Tests passed!");

    $finish();
    #100;
  end

  initial begin
    repeat (2 * SYMBOL_EDGE_TIME * 10 * NUM_CHARS) @(posedge clk);
    $error("Timeout!");
    $fatal();
  end

endmodule
