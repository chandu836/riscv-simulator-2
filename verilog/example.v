module example(
    input clk,
    input a,
    input b,
    output reg y
);

    reg temp;

    always @(posedge clk) begin
        temp <= a ^ b;
        y <= temp & a;
    end

endmodule
