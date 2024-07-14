module Alu(
  input  wire [11:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire zero,
  output wire less,
  output wire [31:0] alu_result
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result);
assign less = alu_result[0];
assign zero = ~(|alu_result);
endmodule


module Agu(
    input clk,
    input reset,
    input is_unsigned,
    input size,
    input [3:0] mem_we,
    input mem_rd,
    input [31:0] src1,
    input [31:0] src2,
    input [31:0] wdata,
    output [31:0] rdata,
    output [31:0] mem_result,
);

wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~src2 : src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

dcache u_dcache(
    .clk            (clk           ),  //
    .reset          (reset          ), //
//to from cpu
    .valid          (data_valid     ),
    .op             (data_op        ),  
    .size           (size      ), //
    .wdata          (wdata     ),      //
    .addr_ok        (data_addr_ok   ),
    .data_ok        (data_data_ok   ),
    .rdata          (rdata     ),      //
    .uncache_en     (data_uncache_en),
    .dcacop_op_en   (dcacop_op_en   ),
    .cacop_op_mode  (cacop_op_mode  ),
    .preld_hint     (preld_hint     ),
    .preld_en       (preld_en       ),
    .tlb_excp_cancel_req (data_tlb_excp_cancel_req),
    .sc_cancel_req  (sc_cancel_req  ),
	.dcache_empty   (dcache_empty   ),
//to from axi 
    .rd_req         (data_rd_req    ), 
    .rd_type        (data_rd_type   ), 
    .rd_addr        (adder_result   ), //
    .rd_rdy         (data_rd_rdy    ), 
    .ret_valid      (data_ret_valid ),    
    .ret_last       (data_ret_last  ), 
    .ret_data       (data_ret_data  ), 
    .wr_req         (data_wr_req    ), 
    .wr_type        (data_wr_type   ), 
    .wr_addr        (adder_result   ), //
    .wr_wstrb       (data_wr_wstrb  ), 
    .wr_data        (data_wr_data   ), 
    .wr_rdy         (data_wr_rdy    ),
    .cache_miss     (ms_dcache_miss )
);

wire [31:0] read_res_b;
wire [31:0] read_res_h;
assign read_res_b = adder_result[1:0]==2'b00 ? rdata: 
                    adder_result[1:0]==2'b01 ? {{24{rdata[15]}},rdata[15:8]}:
                    adder_result[1:0]==2'b10 ? {{24{rdata[23]}},rdata[23:16]}:{{24{rdata[31]}},rdata[31:24]};
assign read_res_h = adder_result[1:0]==2'b00 ? rdata : {{24{rdata[31]}},rdata[31:16]};          
assign mem_result =  bit_width[3]? rdata:
                     bit_width[1] ? {{16{read_res_h[15]&(~is_unsigned)}},read_res_h[15:0]}:
                                       {{24{read_res_b[7]&(~is_unsigned)}},read_res_b[7:0]};


endmodule

module Mul(
  input valid,
  input is_unsigned,
  input use_high,
  input [31:0] multiplicand,
  input [31:0] multiplier,
  output [31:0] result,

);
  signed [63:0] product;
  wire [63:0] uproduct;
  assign product = valid ? multiplicand * multiplier : 64'b0;
  assign uproduct = valid ? multiplicand * multiplier : 64'b0;
  assign result = use_high ? is_unsigned ? uproduct[63:32] : product[63:32] : product[31:0];
endmodule

module Div(
  input valid,
  input is_unsigned,
  input use_mod,
  input [31:0] dividend,
  input [31:0] divisor,
  output [31:0] result,
);
  signed [31:0] quotient,
  signed [31:0] remainder,
  wire [31:0] uquotient,
  wire [31:0] uremainder,
  assign quotient  = dividend / divisor;
  assign remainder = dividend % divisor;

  assign uquotient  = dividend / divisor;
  assign uremainder = dividend % divisor;
  assign result = use_mod?
                   is_unsigned? uremainder : remainder:
                   is_unsigned? iquotient : quotient;

endmodule

module BranchCond (
    input  wire        pre_jump,
    input  wire        may_jump,      // 1 
    input  wire        use_rj_value,  // 1
    input  wire        use_less,      // 1
    input  wire        need_less,     // 1
    input  wire        use_zero,      // 1
    input  wire        need_zero,     // 1
    input  wire        less,
    input  wire        zero,
    input  wire [31:0] pc,
    input  wire [31:0] rj_value,
    input  wire [31:0] imm,
    output wire        need_jump,
    output wire [31:0] jump_target,
    output wire        pre_fail,
    input  wire        flush_IF,
    input  wire        flush_ID,
);
  assign need_jump = may_jump & 
                   ~(use_less & ~(need_less & less| ~need_less & ~ less)) &
                   ~(use_zero & ~(need_zero & zero| ~need_zero & ~ zero ));
  wire [31:0] src1 = use_rj_value ? rj_value : pc;
  wire [31:0] src2 = {imm[29:0], 2'b00};
  assign jump_target = src1 + src2;
  assign pre_fail = ~(need_jump & pre_jump);
  assign flush_ID = need_jump;
  assign flush_IF = need_jump;

endmodule