module uart_receiver #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200)
(
    input clk,
    input reset,

    output [7:0] data_out,
    output data_out_valid,
    input data_out_ready,

    input serial_in
);
    // See diagram in the lab guide
    localparam SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;
    localparam SAMPLE_TIME = SYMBOL_EDGE_TIME / 2;
    localparam CLOCK_COUNTER_WIDTH= $clog2(SYMBOL_EDGE_TIME);

    wire symbol_edge;
    wire sample;
    wire start;
    wire rx_running;

    reg [9:0] rx_shift;
    reg [3:0] bit_counter;
    reg [CLOCK_COUNTER_WIDTH-1:0] clock_counter;
    reg has_byte;

    //--|Signal Assignments|------------------------------------------------------

    // Goes high at every symbol edge
    /* verilator lint_off WIDTH */
    assign symbol_edge = clock_counter == (SYMBOL_EDGE_TIME - 1);
    /* lint_on */

    // Goes high halfway through each symbol
    /* verilator lint_off WIDTH */
    assign sample = clock_counter == SAMPLE_TIME;
    /* lint_on */

    // Goes high when it is time to start receiving a new character
    assign start = !serial_in && !rx_running;

    // Goes high while we are receiving a character
    assign rx_running = bit_counter != 4'd0;

    // Outputs
    assign data_out = rx_shift[8:1];
    assign data_out_valid = has_byte && !rx_running;

    //--|Counters|----------------------------------------------------------------

    // Counts cycles until a single symbol is done
    always @ (posedge clk) begin
        clock_counter <= (start || reset || symbol_edge) ? 0 : clock_counter + 1;
    end

    // Counts down from 10 bits for every character
    always @ (posedge clk) begin
        if (reset) begin
            bit_counter <= 0;
        end else if (start) begin
            bit_counter <= 10;
        end else if (symbol_edge && rx_running) begin
            bit_counter <= bit_counter - 1;
        end
    end

    //--|Shift Register|----------------------------------------------------------
    always @(posedge clk) begin
        if (sample && rx_running) rx_shift <= {serial_in, rx_shift[9:1]};
    end

    //--|Extra State For Ready/Valid|---------------------------------------------
    // This block and the has_byte signal aren't needed in the uart_transmitter
    always @ (posedge clk) begin
        if (reset) has_byte <= 1'b0;
        else if (bit_counter == 1 && symbol_edge) has_byte <= 1'b1;
        else if (data_out_ready) has_byte <= 1'b0;
    end
endmodule
