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
    input clk,
    input reset,
    input [31:0] mem_addr,
    input is_unsigned,
    input mem_we,
    input [3:0] bit_width,
    input mem_rd,
    input [31:0] wdata,
    output[31:0] mem_result,
    output dcache_ok,
    input [`EXM_DCACHE_RD -1:0] dcache_rdata_bus,
    output [`EXM_DCACHE_WD -1:0] dcache_wdata_bus,
    output excp_ale,
    input csr_datm
);

// reg         wait_rready;
// reg         wait_rvalid;
// reg         wait_wready;
wire [3:0] we;
wire [31:0] write_data;
wire [31:0] read_data0;
wire [31:0] read_data;
reg [2:0]   waits; // 2=wready, 1=rvalid, 0=rready

wire        dcache_valid = ~excp_ale&((mem_we && (waits==3'b000 || waits==3'b100)) || (mem_rd && (waits==3'b000 || waits==3'b001)));
wire        dcache_op = (mem_rd) ? 1'b0 :1'b1;       // 0: read, 1: write
wire [31:0] dcache_addr = mem_addr;
wire        dcache_uncached = (mem_addr[31:20] == 12'hbfa);
wire [ 3:0] dcache_awstrb = we;
wire [31:0] dcache_wdata = write_data;
wire        dcache_cacop_en = 1'b0;
wire [ 1:0] dcache_cacop_code = 2'b0; // code[4:3]
wire [31:0] dcache_cacop_addr = 32'b0;

wire        dcache_ready;
wire        dcache_rvalid;
wire [31:0] dcache_rdata;

wire [4:0] index = {3'b0,mem_addr[1:0]}<<3;

assign we = (bit_width==4'b0001) ? (index==5'b0) ? 4'b0001 : (index==5'b01000) ? 4'b0010 : (index==5'b10000) ? 4'b0100 : 4'b1000 :
            (bit_width==4'b0011) ? (index==5'b0) ? 4'b0011 : 4'b1100 :
            (bit_width==4'b1111) ? 4'b1111 : 4'b0000;
assign write_data = wdata << index;

assign dcache_wdata_bus = {dcache_valid, dcache_op, dcache_addr, dcache_uncached, dcache_awstrb, dcache_wdata, 
        dcache_cacop_en, dcache_cacop_code, dcache_cacop_addr};

assign {dcache_ready, dcache_rvalid, dcache_rdata} = dcache_rdata_bus;

assign read_data0 = dcache_rdata >> index;
assign read_data = (bit_width == 4'b0001)? {{24{read_data0[7] & !is_unsigned}},read_data0[7:0]}:
                   (bit_width == 4'b0011)? {{16{read_data0[15]& !is_unsigned}},read_data0[15:0]}:
                    read_data0;
assign mem_result = (dcache_rvalid) ? read_data : 32'b0;

assign excp_ale = (&bit_width) ? mem_addr[0] | mem_addr[1] :
                ~|(bit_width ^4'b0011) ? mem_addr[0] : 1'b0;

//assign dcache_ok = (mem_rd && dcache_rvalid) || (mem_we && dcache_ready) || (!mem_rd && !mem_we);
//assign dcache_ok = (mem_rd && !wait_rready && !wait_rvalid) || (mem_we && !wait_wready) || (!mem_rd && !mem_we);
assign dcache_ok = !(waits==3'b000 && mem_rd && (!dcache_ready || !dcache_rvalid)) &&
                   !(waits==3'b000 && mem_we && !dcache_ready) &&
                   !(waits==3'b001 && (!dcache_ready || !dcache_rvalid)) &&
                   !(waits==3'b010 && !dcache_rvalid) &&
                   !(waits==3'b100 && !dcache_ready);

always @(posedge clk) begin
    if(reset | excp_ale) begin
      waits<=3'b0;
    end
    else if(mem_rd && waits==3'b000) begin
      if(!dcache_ready) begin
        waits<=3'b001; 
      end else if(dcache_ready) begin
        waits<=3'b010;
      end
    end
    else if(mem_we && waits==3'b000) begin
      if(!dcache_ready) begin
        waits<=3'b100;
      end else if(dcache_ready) begin
        waits<=3'b000;
      end
    end
    else if(waits==3'b001) begin
      if(dcache_ready) begin
        waits<=3'b010;
      end
    end
    else if(waits==3'b010) begin

      if(dcache_rvalid) begin
        waits<=3'b000;
      end
    end
    else if(waits==3'b100) begin
      if(dcache_ready) begin
        waits<=3'b000;
      end
    end
    else begin
      waits<=waits;
    end
end
// always @(posedge clk) begin
//     if(reset) begin
//       waits<=3'b0;
//     end
//     else if(mem_rd && waits==3'b000) begin
//       if(!dcache_ready) begin
//         waits<=3'b001; 
//       end else if(dcache_ready && !dcache_rvalid) begin
//         waits<=3'b010;
//       end else if(dcache_ready && dcache_rvalid) begin
//         waits<=3'b000;
//       end
//     end
//     else if(mem_we && waits==3'b000) begin
//       if(!dcache_ready) begin
//         waits<=3'b100;
//       end else if(dcache_ready) begin
//         waits<=3'b000;
//       end
//     end
//     else if(waits==3'b001) begin
//       if(dcache_ready && !dcache_rvalid) begin
//         waits<=3'b010;
//       end else if(dcache_ready && dcache_rvalid) begin
//         waits<=3'b000;
//       end
//     end
//     else if(waits==3'b010) begin
//       if(dcache_rvalid) begin
//         waits<=3'b000;
//       end
//     end
//     else if(waits==3'b100) begin
//       if(dcache_ready) begin
//         waits<=3'b000;
//       end
//     end
//     else begin
//       waits<=waits;
//     end
// end

endmodule


// module MulCon(
//   input valid,
//   input is_unsigned,
//   input use_high,
//   input wire [31:0] src1,
//   input wire [31:0] src2,
//   output [31:0] result
// );
//   wire signed [63:0] product;
//   wire [63:0] uproduct;
//   Umul Umul(
//     .multiplicand(src1),
//     .multiplier(src2),
//     .product(uproduct)
//   );

//   mul mul(
//     .multiplicand(src1),
//     .multiplier(src2),
//     .product(product)
//   );
//   // wire signed [31:0] multiplicand = umultiplicand;
//   // wire signed [31:0] multiplier = umultiplier;
//   // wire signed [63:0] product;
//   // /* verilator lint_off UNUSED */
//   // wire [63:0] uproduct;
//   // /* verilator lint_on UNUSED */

//   // assign product = valid ? multiplicand * multiplier : 64'b0;
//   // assign uproduct = valid ? umultiplicand * umultiplier : 64'b0;
//   assign result = use_high ? is_unsigned ? uproduct[63:32] : product[63:32] : product[31:0];
// endmodule

module DivCon(
  input valid,
  input is_unsigned,
  input use_mod,
  input wire [31:0] src1,
  input wire [31:0] src2,
  output [31:0] result
);

  //wire signed [31:0] dividend = udividend[31:0];
  //wire signed [31:0] divisor = udivisor[31:0];
  wire signed [31:0] quotient;
  wire signed [31:0] remainder;
  wire [31:0] uquotient;
  wire [31:0] uremainder;
  
  Udiv_temp udiv(
    .dividend(src1),
    .divisor(src2),
    .quotient(uquotient),
    .remainder(uremainder)
  );
  div_temp div(
    .dividend(src1),
    .divisor(src2),
    .quotient(quotient),
    .remainder(remainder)
  );
  // assign quotient  = valid ? dividend / divisor : 32'b0;
  // assign remainder = valid ? dividend % divisor : 32'b0;

  // assign uquotient  = valid ? udividend / udivisor :32'b0;
  // assign uremainder = valid ? udividend % udivisor :32'b0;
  assign result = use_mod?
                   is_unsigned? uremainder : remainder:
                   is_unsigned? uquotient : quotient;

endmodule


// module Umul (
//     input  [31:0] multiplicand,  // 32-bit unsigned multiplicand
//     input  [31:0] multiplier,    // 32-bit unsigned multiplier
//     output [63:0] product        // 64-bit unsigned product
// );
//   assign product = multiplicand * multiplier;
// endmodule

// module mul (
//     input signed [31:0] multiplicand, // 32-bit signed multiplicand
//     input signed [31:0] multiplier,  // 32-bit signed multiplier
//     output signed [63:0] product     // 64-bit signed product
// );
//   // 对于32位有符号数，由于已经是完整的32位，包括符号位，因此不需要额外扩展
//   assign product = multiplicand * multiplier;
// endmodule

module Udiv_temp (
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    output wire [31:0] quotient,
    output wire [31:0] remainder
);

  assign quotient  = dividend / divisor;
  assign remainder = dividend % divisor;

endmodule
module div_temp (
    input signed [31:0] dividend,  // 32位有符号被除数
    input signed [31:0] divisor,  // 32位有符号除数
    output wire signed [31:0] quotient,  // 商
    output wire signed [31:0] remainder  // 余数
);

  assign quotient  = dividend / divisor;
  assign remainder = dividend % divisor;

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
