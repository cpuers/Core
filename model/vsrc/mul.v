
module mul (
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    input use_high,
    output [31:0] mul_result
);

    wire [63:0] result;
    assign mul_result = use_high ? result[63:32] : result[31:0];

    WallaceTree32 mywt(
        .x(x),
        .y(y),
        .mul_signed(mul_signed),
        .result(result)
    );  

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
    output [17*64-1:0] partialProduct
//    ,output wire [15:0] neg, 
//    output wire [15:0] two,
//    output wire [15:0] zero
);
    wire [63:0] pp_arr [16:0];
    genvar i;
    generate for (i = 0; i < 17; i = i+1) begin: partialProductConvert
        assign partialProduct[64*(i+1)-1: 64*i] = pp_arr[i];
    end endgenerate
    wire [34:0] ex_y = {mul_signed & y[31], mul_signed & y[31], y, 1'b0};
    wire [63:0] ex_x;
    assign ex_x = (mul_signed & x[31]) ? {32'hffffffff, x} : {32'd0, x};

    wire [63:0] pp_m2 = (-ex_x)<<1;
    wire [63:0] pp_m1 = -ex_x;
    wire [63:0] pp_1  = ex_x;
    wire [63:0] pp_2  = (ex_x << 1);
    
    wire [16:0] neg, two, zero;
    
    genvar j;
    generate for (j = 0; j < 17; j=j+1) begin
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

module csa_adder(
    input [63:0] a,
    input [63:0] b,
    input [63:0] c,
    output [63:0] sum,
    output [63:0] carry
);

    genvar i;
    generate
        for (i = 0; i<64; i = i+1) begin
            assign carry[i] = (a[i] & b[i]) || (b[i] & c[i]) || (a[i] & c[i]);
            assign sum[i] = a[i] ^ b[i] ^ c[i]; 
        end
    endgenerate

endmodule

module WallaceTree32(
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    output [63:0] result
);
    
    wire [63:0] pp [16:0];
    rad4Booth myboo(
        .x(x),
        .y(y),
        .mul_signed(mul_signed),
        .partialProduct({pp[16], pp[15], pp[14], pp[13], pp[12], pp[11], pp[10], pp[9], pp[8], 
    pp[7], pp[6], pp[5], pp[4], pp[3], pp[2], pp[1], pp[0]})
    );
    
    wire [63:0] l1 [9:0];
    assign l1[1][0] = 1'b0;
    assign l1[3][0] = 1'b0;
    assign l1[5][0] = 1'b0;
    assign l1[7][0] = 1'b0;
    assign l1[9][0] = 1'b0;
    
    csa_adder l1a1(
        .a(pp[0]), .b(pp[1]), .c(pp[2]),
        .sum(l1[0]),
        .carry(l1[1][63:1])
    );
    csa_adder l1a2(
        .a(pp[3]), .b(pp[4]), .c(pp[5]),
        .sum(l1[2]),
        .carry(l1[3][63:1])
    );
    csa_adder l1a3(
        .a(pp[6]), .b(pp[7]), .c(pp[8]),
        .sum(l1[4]),
        .carry(l1[5][63:1])
    );
    csa_adder l1a4(
        .a(pp[9]), .b(pp[10]), .c(pp[11]),
        .sum(l1[6]),
        .carry(l1[7][63:1])
    );
    csa_adder l1a5(
        .a(pp[12]), .b(pp[13]), .c(pp[14]),
        .sum(l1[8]),
        .carry(l1[9][63:1])
    );
    
    
    wire [63:0] l2 [7:0];
    assign l2[1][0] = 1'b0;
    assign l2[3][0] = 1'b0;
    assign l2[5][0] = 1'b0;
    assign l2[7][0] = 1'b0;
    
    csa_adder l2a1(
        .a(l1[0]), .b(l1[1]), .c(l1[2]),
        .sum(l2[0]),
        .carry(l2[1][63:1])
    );
    csa_adder l2a2(
        .a(l1[3]), .b(l1[4]), .c(l1[5]),
        .sum(l2[2]),
        .carry(l2[3][63:1])
    );
    csa_adder l2a3(
        .a(l1[6]), .b(l1[7]), .c(l1[8]),
        .sum(l2[4]),
        .carry(l2[5][63:1])
    );
    csa_adder l2a4(
        .a(l1[9]), .b(pp[15]), .c(pp[16]),
        .sum(l2[6]),
        .carry(l2[7][63:1])
    );
    
    
    wire [63:0] l3 [3:0];
    assign l3[1][0] = 1'b0;
    assign l3[3][0] = 1'b0;
    
    csa_adder l3a1(
        .a(l2[0]), .b(l2[1]), .c(l2[2]),
        .sum(l3[0]),
        .carry(l3[1][63:1])
    );
    csa_adder l3a2(
        .a(l2[3]), .b(l2[4]), .c(l2[5]),
        .sum(l3[2]),
        .carry(l3[3][63:1])
    );
    
    
    wire [63:0] l4 [3:0];
    assign l4[1][0] = 1'b0;
    assign l4[3][0] = 1'b0;
    
    csa_adder l4a1(
        .a(l3[0]), .b(l3[1]), .c(l3[2]),
        .sum(l4[0]),
        .carry(l4[1][63:1])
    );
    csa_adder l4a2(
        .a(l3[3]), .b(l2[6]), .c(l2[7]),
        .sum(l4[2]),
        .carry(l4[3][63:1])
    );
    
    wire [63:0]l5, l5c, l6, l6c;
    assign l5c[0] = 1'b0;
    assign l6c[0] = 1'b0;
    
    csa_adder l5a(
        .a(l4[0]), .b(l4[1]), .c(l4[2]),
        .sum(l5),
        .carry(l5c[63:1])
    );
    
    csa_adder l6a(
        .a(l4[3]), .b(l5), .c(l5c),
        .sum(l6),
        .carry(l6c[63:1])
    );
    
    assign result = l6 + l6c;

endmodule



