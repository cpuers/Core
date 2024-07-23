

// module booth2_encoder(
//     input [31:0] data,
//     output [15:0] mul2,
//     output 
// );

// endmodule

// module wallace_tree(
    
// );



// endmodule


module mul(
    input mul_clk, reset,
    input mul_signed,
    input [31:0] x, y, //x扩展至64位 y扩展至33位 区别有无符号
    output [63:0] result
    );

    assign reset = x * y;

endmodule