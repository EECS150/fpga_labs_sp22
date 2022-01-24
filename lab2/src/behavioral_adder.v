module behavioral_adder (
    input [13:0] a,
    input [13:0] b,
    output [14:0] sum
);
    assign sum = a + b;
endmodule
