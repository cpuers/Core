`include "config.vh"

module adder (
    input  [`WIDTH-1:0]   a,
    input  [`WIDTH-1:0]   b,
    output [`WIDTH-1:0]   f
);
    assign f = a + b;
endmodule
