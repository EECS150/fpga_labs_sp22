module fsm #(
    parameter CYCLES_PER_SECOND = 125_000_000,
    parameter WIDTH = $clog2(CYCLES_PER_SECOND)
)(
    input clk,
    input rst,
    input [2:0] buttons,
    output [3:0] leds,
    output [23:0] fcw,
    output [1:0] leds_state
);
    assign leds = 0;
    assign fcw = 0;
    assign leds_state = 0;

    wire [1:0] addr;
    wire wr_en, rd_en;
    wire [23:0] d_in, d_out;

    fcw_ram notes (
        .clk(clk),
        .rst(rst),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .addr(addr),
        .d_in(d_in),
        .d_out(d_out)
    );
endmodule
