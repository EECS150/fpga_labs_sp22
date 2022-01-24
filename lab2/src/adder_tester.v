module adder_tester (
    output [13:0] adder_operand1,
    output [13:0] adder_operand2,
    input [14:0] structural_sum,
    input [14:0] behavioral_sum,
    input clk,
    output test_fail
);
    reg error = 0;
    assign test_fail = error;

    reg [27:0] operands = 0;
    assign adder_operand1 = operands[13:0];
    assign adder_operand2 = operands[27:14];

    // Iterate the operands continuously until all combinations are tried
    always @ (posedge clk) begin
        operands <= operands + 1'd1;
    end

    // If we encounter a case where the adders don't match, or we have already
    // encountered one such case, flip the error register high and hold it there.
    always @ (posedge clk) begin
        if (structural_sum != behavioral_sum) begin
            error <= 1'b1;
        end
        else begin
            error <= error;
        end
    end
endmodule
