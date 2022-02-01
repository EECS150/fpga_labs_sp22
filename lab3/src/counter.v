module counter #(
    parameter CYCLES_PER_SECOND = 125_000_000
)(
    input clk,
    input ce,
    input [3:0] buttons,
    output [3:0] leds
);
    reg [3:0] counter = 0;
    assign leds = counter;

    always @(posedge clk) begin
        if (buttons[0])
            counter <= counter + 4'd1;
        else if (buttons[1])
            counter <= counter - 4'd1;
        else if (buttons[3])
            counter <= 4'd0;
        else
            counter <= counter;
    end
endmodule

