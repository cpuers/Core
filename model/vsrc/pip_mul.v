
module mul (
    input [31:0] x,
    input [31:0] y,
    input mul_signed,
    input use_high,
    input mul_clk, 
    input reset,
    output mul_ok,
    output [31:0] mul_result
);


    wire [63:0] result;
    wire [63:0] result_s, result_us;
    
    mul_ip_signed mul_s(
        .clk(mul_clk),
        .en(1'b1),
        .A(x),
        .B(y),
        .P(result_s)
    );
    
    mul_ip_unsigned mul_us(
        .clk(mul_clk),
        .en(1'b1),
        .A(x),
        .B(y),
        .P(result_us)
    );
    
    assign result = mul_signed ? result_s : result_us; 
    assign mul_result = use_high ? result[63:32] : result[31:0];

    /*
    reg [31:0] x_r, y_r;
    reg mul_signed_r, mul_ok;
    reg status;
    always @(posedge mul_clk) begin
        if(reset) begin
            mul_ok <= 1'b0;
            status <= 1'b0;
        end else if(status == 1'b0) begin
            x_r <= x;
            y_r <= y;
            mul_signed_r <= mul_signed;
            status <= 1'b1;
        end else if (status <= 1'b1) begin
            status <= 1'b0;
            mul_ok <= 1'b1;
        end
    end
    WallaceTree32 mywt(
        .x(x_r),
        .y(y_r),
        .mul_signed(mul_signed_r),
        .result(result)
    );
    */
    
endmodule
