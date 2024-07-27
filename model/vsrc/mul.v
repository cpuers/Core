

module mul (
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    // input clock, 
    // input reset,
    output [63:0] result
    //output avoidCompileErr
);
    //assign avoidCompileErr = clock ^ reset;

    WallaceTree mywt(
        .x(x),
        .y(y),
        .mul_signed(mul_signed),
        .result(result)
    );

    // wire [63:0] ex_x = (mul_signed & x[31]) ? {32'h11111111, x} : {32'd0, x};
    // wire [63:0] ex_y = (mul_signed & y[31]) ? {32'h11111111, y} : {32'd0, y};
    
    // assign result = ex_x * ex_y;

endmodule

module boothEncoder (
    input [2:0] a,
    output neg,
    output zero,
    //output one,
    output two
);
    
    assign neg  = a[2];
    assign zero = (a == 3'b000) || (a == 3'b111);
    assign two  = (a == 3'b100) || (a == 3'b011);
    //assign one = ~(zero | two); 

endmodule

module rad4Booth(
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    output [16*64-1:0] partialProduct
//    ,output wire [15:0] neg, 
//    output wire [15:0] two,
//    output wire [15:0] zero
);
    wire [63:0] pp_arr [15:0];
    genvar i;
    generate for (i = 0; i < 16; i = i+1) begin: partialProductConvert
        assign partialProduct[64*(i+1)-1: 64*i] = pp_arr[i];
    end endgenerate
    wire [33:0] ex_y = {mul_signed & y[31], y, 1'b0};
    wire [63:0] ex_x;
    assign ex_x = (mul_signed & x[31]) ? {32'hffffffff, x} : {32'd0, x};

    wire [63:0] pp_m2 = -(ex_x << 1);
    wire [63:0] pp_m1 = -ex_x;
    wire [63:0] pp_1  = ex_x;
    wire [63:0] pp_2  = (ex_x << 1);
    
    wire [15:0] neg, two, zero;
    
    genvar j;
    generate for (j = 0; j < 16; j=j+1) begin
        boothEncoder be(
            .a(ex_y[j*2+2:j*2]),
            .neg(neg[j]),
            .two(two[j]),
            .zero(zero[j])
        );
        assign pp_arr[j] = 
        (zero[j] ? 
            64'd0 : 
            (neg[j] ? 
                (two[j] ? (pp_m2[63:0] << (j*2)) : (pp_m1[63:0] << (j*2))) : 
                (two[j] ? ( pp_2[63:0] << (j*2)) : ( pp_1[63:0] << (j*2))) 
            )
        ); 
    end endgenerate
endmodule

module compressor_42 (
    input [63:0] a,
    input [63:0] b,
    input [63:0] c,
    input [63:0] d,
    output [63:0] sum,
    output [63:0] carry,
    input Em1,
    output overflow
    //,output [63:0]debugE
);
    wire [63:0] E, xor_abcd;
    //assign debugE = E;
    
    assign overflow    = E[63];
    
    assign xor_abcd[0]  = d[0] ^ c[0] ^ b[0] ^ a[0];
    assign sum[0]       = xor_abcd[0] ^ Em1;
    assign carry[0]     = xor_abcd[0] ? Em1 : a[0];
    //assign E[0]        = ((d[0] ^ c[0]) & b[0]) | ((~(d[0] ^ c[0])) & b[0]);
    assign E[0]         = (d[0] & c[0]) || (c[0] & b[0]) || (d[0] & b[0]);
    
    genvar i;
    generate 
        for (i = 1; i < 64; i = i+1) begin
            //assign E[i]        = ((d[i] ^ c[i]) & b[i]) | ((~(d[i] ^ c[i])) & b[i]);
            assign E[i]        = (d[i] & c[i]) || (c[i] & b[i]) || (d[i] & b[i]);
            assign xor_abcd[i] = (d[i] ^ c[i]) ^ (b[i] ^ a[i]);
            assign sum[i]      = xor_abcd[i] ^ E[i-1];
            assign carry[i]    = xor_abcd[i] ? E[i-1] : a[i];
        end
    endgenerate
endmodule

module WallaceTree(
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    output [63:0] result,
    output overflow
);
    
    wire [63:0] pp [15:0];
    rad4Booth myboo(
        .x(x),
        .y(y),
        .mul_signed(mul_signed),
        .partialProduct({pp[15], pp[14], pp[13], pp[12], pp[11], pp[10], pp[9], pp[8], 
    pp[7], pp[6], pp[5], pp[4], pp[3], pp[2], pp[1], pp[0]})
    );
    
    
    wire [63:0] l1res00, l1res01, l1res10, l1res11, l1res20, l1res21, l1res30, l1res31;
    wire cout1_0, cout1_1, cout1_2, cout1_3;
    assign l1res00[0] = 1'b0;
    assign l1res10[0] = 1'b0;
    assign l1res20[0] = 1'b0;
    assign l1res30[0] = 1'b0;
    
    compressor_42 l1c1(
        .a(pp[0]),  .b(pp[1]),  .c(pp[2]),  .d(pp[3]),  .carry(l1res00[63:1]), .sum(l1res01), 
        .Em1(0),       .overflow(cout1_0)
    );
    compressor_42 l1c2(
        .a(pp[4]),  .b(pp[5]),  .c(pp[6]),  .d(pp[7]),  .carry(l1res10[63:1]), .sum(l1res11), 
        .Em1(0), .overflow(cout1_1)
    );
    compressor_42 l1c3(
        .a(pp[8]),  .b(pp[9]),  .c(pp[10]), .d(pp[11]), .carry(l1res20[63:1]), .sum(l1res21), 
        .Em1(0), .overflow(cout1_2)
    );
    compressor_42 l1c4(
        .a(pp[12]), .b(pp[13]), .c(pp[14]), .d(pp[15]), .carry(l1res30[63:1]), .sum(l1res31), 
        .Em1(0), .overflow(cout1_3)
    );
    
    
    wire [63:0] l2res00, l2res01, l2res10, l2res11;
    wire cout2_0, cout2_1;
    assign l2res00[0] = 0;
    assign l2res10[0] = 0;
    
    compressor_42 l2c1(
        .a(l1res00), .b(l1res01), .c(l1res10), .d(l1res11), .carry(l2res00[63:1]), .sum(l2res01), 
        .Em1(0), .overflow(cout2_0)
    );
    compressor_42 l2c2(
        .a(l1res20), .b(l1res21), .c(l1res30), .d(l1res31), .carry(l2res10[63:1]), .sum(l2res11), 
        .Em1(0), .overflow(cout2_1)
    );
    
    
    wire [63:0] l3res00, l3res01;
    wire cout3_0;
    assign l3res00[0] = 0;
    
    compressor_42 l3c(
        .a(l2res00), .b(l2res01), .c(l2res10), .d(l2res11), .carry(l3res00[63:1]), .sum(l3res01), 
        .Em1(0), .overflow(cout3_0)
    );
    
    assign result   = l3res00 + l3res01;
    assign overflow = cout3_0;
    
endmodule


