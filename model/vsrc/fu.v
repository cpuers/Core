`include "define.vh"
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
/* verilator lint_off UNUSED */
wire [63:0] sr64_result;
/* verilator lint_on UNUSED */
wire [31:0] sr_result;


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire [31:0] adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 32'b0001      : 32'b0;
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
    input [2:0] alu_op,
    input mem_we,
    input [3:0] mem_ewe,
    input mem_rd,
    input [31:0] src1,
    input [31:0] src2,
    input [31:0] wdata,
    output [`EXM_DCACHE_WD -1:0] dcache_wdata_bus
);

wire        dcache_valid = mem_we | mem_rd;
wire        dcache_op = (mem_rd) ? 1'b0 :1'b1;       // 0: read, 1: write
wire [31:0] dcache_addr;
wire        dcache_uncached = 1'b0;
wire [ 3:0] dcache_awstrb = mem_ewe;
wire [31:0] dcache_wdata = wdata;
wire        dcache_cacop_en = 1'b0;
wire [ 1:0] dcache_cacop_code = 2'b0; // code[4:3]
wire [31:0] dcache_cacop_addr = 32'b0;

wire [31:0] adder_a;
wire [31:0] adder_b;
wire [31:0] adder_cin;
/* verilator lint_off UNUSED */
wire        adder_cout;
/* verilator lint_on UNUSED */
wire op_sub  = alu_op[0];
wire op_slt  = alu_op[1];
wire op_sltu = alu_op[2];

assign adder_a   = src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~src2 : src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 32'b0001      : 32'b0;
assign {adder_cout, dcache_addr} = adder_a + adder_b + adder_cin;

assign dcache_wdata_bus = {dcache_valid, dcache_op, dcache_addr, dcache_uncached, dcache_awstrb, dcache_wdata, 
        dcache_cacop_en, dcache_cacop_code, dcache_cacop_addr};

// wire [31:0] read_res_b;
// wire [31:0] read_res_h;
// assign read_res_b = adder_result[1:0]==2'b00 ? rdata: 
//                     adder_result[1:0]==2'b01 ? {{24{rdata[15]}},rdata[15:8]}:
//                     adder_result[1:0]==2'b10 ? {{24{rdata[23]}},rdata[23:16]}:{{24{rdata[31]}},rdata[31:24]};
// assign read_res_h = adder_result[1:0]==2'b00 ? rdata : {{24{rdata[31]}},rdata[31:16]};          
// assign mem_result =  bit_width[3]? rdata:
//                      bit_width[1] ? {{16{read_res_h[15]&(~is_unsigned)}},read_res_h[15:0]}:
//                                        {{24{read_res_b[7]&(~is_unsigned)}},read_res_b[7:0]};


endmodule

module Mul(
  input valid,
  input is_unsigned,
  input use_high,
  input [31:0] multiplicand,
  input [31:0] multiplier,
  output [31:0] result
);
  wire [63:0] product;
  /* verilator lint_off UNUSED */
  wire [63:0] uproduct;
  /* verilator lint_on UNUSED */
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
  output [31:0] result
);
  wire [31:0] quotient;
  wire [31:0] remainder;
  wire [31:0] uquotient;
  wire [31:0] uremainder;
  assign quotient  = valid ? dividend / divisor : 32'b0;
  assign remainder = valid ? dividend % divisor : 32'b0;

  assign uquotient  = valid ? dividend / divisor :32'b0;
  assign uremainder = valid ? dividend % divisor :32'b0;
  assign result = use_mod?
                   is_unsigned? uremainder : remainder:
                   is_unsigned? uquotient : quotient;

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
    /* verilator lint_off UNUSED */
    input  wire [31:0] imm,
    output wire [31:0] jump_target,
    output wire        pre_fail
);
  wire need_jump;
  assign need_jump = may_jump & 
                   ~(use_less & ~(need_less & less| ~need_less & ~ less)) &
                   ~(use_zero & ~(need_zero & zero| ~need_zero & ~ zero ));
  wire [31:0] src1 = use_rj_value ? rj_value : pc;
  wire [31:0] src2 = {imm[29:0], 2'b00};
  assign jump_target = src1 + src2;
  assign pre_fail = (need_jump ^ pre_jump);

endmodule
