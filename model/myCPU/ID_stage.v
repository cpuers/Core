`include "define.vh"

module ID_stage (
    input clk,
    input rst,
    // for IF
    input [`IB_DATA_BUS_WD-1:0] IF_instr0,
    input [`IB_DATA_BUS_WD-1:0] IF_instr1,
    input IB_empty,

    output [1:0] IF_pop_op,

    //for EXE
    output [`DS_TO_ES_BUS_WD-1:0] EXE_instr0,
    output [`DS_TO_ES_BUS_WD-1:0] EXE_instr1,
    output EXE_instr0_valid,
    output EXE_instr1_valid,
    input EXE_ready,
    input flush_ID,

    //for regfile
    output [ 4:0] read_addr0,
    output [ 4:0] read_addr1,
    output [ 4:0] read_addr2,
    output [ 4:0] read_addr3,
    input  [31:0] read_data0,
    input  [31:0] read_data1,
    input  [31:0] read_data2,
    input  [31:0] read_data3

);
  wire EXE_instr0_valid_w;
  wire EXE_instr1_valid_w;

  reg [`DS_TO_ES_BUS_WD:0] EXE_instr0_r;
  reg [`DS_TO_ES_BUS_WD:0] EXE_instr1_r;
  always @(posedge clk) begin
    if (rst | flush_ID) begin
      EXE_instr0_r <= 0;
      EXE_instr1_r <= 0;
    end 
    else if (!EXE_ready) 
    begin
      EXE_instr0_r <= EXE_instr0_r;
      EXE_instr1_r <= EXE_instr1_r;  
    end
    else begin
      EXE_instr0_r[`DS_TO_ES_BUS_WD-1:0] <= EXE_instr0;
      EXE_instr1_r[`DS_TO_ES_BUS_WD-1:0] <= EXE_instr1;
      EXE_instr0_r[`DS_TO_ES_BUS_WD] <= EXE_instr0_valid_w;
      EXE_instr1_r[`DS_TO_ES_BUS_WD] <= EXE_instr1_valid_w;
    end
  end

  assign EXE_instr0_valid = EXE_instr0_r[`DS_TO_ES_BUS_WD];
  assign EXE_instr1_valid = EXE_instr1_r[`DS_TO_ES_BUS_WD];


  wire [4:0] instr0_dest;
  wire instr0_gr_we;
  wire instr0_use_rj;
  wire instr0_use_rkd;
  wire [4:0] instr1_dest;
  wire instr1_gr_we;
  wire instr1_use_rj;
  wire instr1_use_rkd;
  wire instr0_may_jump;
  wire instr1_may_jump;
  wire instr0_is_ls;
  wire instr1_is_ls;
  ID_decoder ID_decoder0 (
      .fs_to_ds_bus(IF_instr0[`IB_DATA_BUS_WD-2:0]),
      .ds_to_es_bus(EXE_instr0),
      .rf_raddr1(read_addr0),
      .rf_raddr2(read_addr1),
      .rf_rdata1(read_data0),
      .rf_rdata2(read_data1),
      .rg_en(instr0_gr_we),
      .use_rj(instr0_use_rj),
      .use_rkd(instr0_use_rkd),
      .dest(instr0_dest),
      .may_jump(instr0_may_jump),
      .is_ls(instr0_is_ls)
  );
  ID_decoder ID_decoder1 (
      .fs_to_ds_bus(IF_instr1[`IB_DATA_BUS_WD-2:0]),
      .ds_to_es_bus(EXE_instr1),
      .rf_raddr1(read_addr2),
      .rf_raddr2(read_addr3),
      .rf_rdata1(read_data2),
      .rf_rdata2(read_data3),
      .rg_en(instr1_gr_we),
      .use_rj(instr1_use_rj),
      .use_rkd(instr1_use_rkd),
      .dest(instr1_dest),
      .may_jump(instr1_may_jump),
      .is_ls(instr1_is_ls)
  );

  // 判断发射逻辑
  wire need_single;
  wire IF_instr0_valid;
  wire IF_instr1_valid;
  assign IF_instr0_valid = IF_instr0[`DS_TO_ES_BUS_WD-1];
  assign IF_instr1_valid = IF_instr1[`DS_TO_ES_BUS_WD-1];
  assign need_single =  instr0_may_jump|
                        ((|instr0_dest) & 
                          instr0_gr_we 
                        &((instr0_dest==read_addr2 & instr1_use_rj) |
                         (instr1_dest==read_addr3 & instr1_use_rkd))) |
                         instr0_is_ls |instr1_is_ls
                         ;
  assign IF_pop_op[0] = IF_instr0_valid & EXE_ready;
  assign IF_pop_op[1] = IF_instr1_valid & EXE_ready;
  assign EXE_instr0_valid_w = IB_empty & IF_instr0_valid;
  assign EXE_instr1_valid_w = IB_empty & IF_instr1_valid & ~need_single;
endmodule

module ID_decoder (
    input [`IB_DATA_BUS_WD-2:0] fs_to_ds_bus,
    //to es
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus,

    // judge RAW 
    output is_ls,
    output rg_en,
    output use_rj,
    output use_rkd,
    output [4:0] dest,
    output may_jump,
    output [4:0] rf_raddr1,
    input [31:0] rf_rdata1,
    output [4:0] rf_raddr2,
    input [31:0] rf_rdata2
);
  wire        use_src1;

  wire        use_rj_value;
  wire        use_less;
  wire        need_less;

  wire        use_zero;
  wire        need_zero;

  wire        br_taken;
  wire [31:0] br_target;

  wire [31:0] ds_pc;
  wire        pc_is_jump;
  wire [31:0] ds_inst;


  wire        ds_ready_go;

  wire [11:0] alu_op;

  wire [ 3:0] bit_width;
  wire        src1_is_pc;
  wire        src2_is_imm;
  wire        res_from_mem;
  wire        dst_is_r1;
  wire        gr_we;
  wire        mem_we;
  wire        src_reg_is_rd;
  wire [31:0] rj_value;
  wire [31:0] rkd_value;
  wire [31:0] imm;
  wire [31:0] br_offs;
  wire [31:0] jirl_offs;

  wire [ 5:0] op_31_26;
  wire [ 3:0] op_25_22;
  wire [ 1:0] op_21_20;
  wire [ 4:0] op_19_15;
  wire [ 4:0] rd;
  wire [ 4:0] rj;
  wire [ 4:0] rk;
  wire [11:0] i12;
  wire [19:0] i20;
  wire [15:0] i16;
  wire [25:0] i26;

  wire [63:0] op_31_26_d;
  wire [15:0] op_25_22_d;
  wire [ 3:0] op_21_20_d;
  wire [31:0] op_19_15_d;

  wire        inst_add_w;
  wire        inst_sub_w;

  wire        inst_slt;
  wire        inst_sltu;

  wire        inst_slti;
  wire        inst_sltui;

  wire        inst_nor;
  wire        inst_and;
  wire        inst_or;
  wire        inst_xor;

  wire        inst_andi;
  wire        inst_ori;
  wire        inst_xori;

  wire        inst_slli_w;
  wire        inst_srli_w;
  wire        inst_srai_w;


  wire        inst_sll_w;
  wire        inst_srl_w;
  wire        inst_sra_w;

  wire        inst_addi_w;
  wire        inst_ld_w;
  wire        inst_ld_b;
  wire        inst_ld_h;
  wire        inst_ld_bu;
  wire        inst_ld_hu;

  wire        inst_st_w;
  wire        inst_st_b;
  wire        inst_st_h;

  wire        inst_jirl;
  wire        inst_b;
  wire        inst_bl;
  wire        inst_beq;
  wire        inst_bne;
  wire        inst_blt;
  wire        inst_bge;
  wire        inst_bltu;
  wire        inst_bgeu;

  wire        inst_lu12i_w;
  wire        inst_pcaddu;

  wire        inst_mul_w;
  wire        inst_mulh_w;
  wire        inst_mulhu_w;

  wire        inst_div_w;
  wire        inst_mod_w;
  wire        inst_divu_w;
  wire        inst_modu_w;

  wire        use_mul;
  wire        use_high;
  wire        is_unsigned;

  wire        use_div;
  wire        use_mod;

  wire        need_ui5;
  wire        need_si12;
  wire        need_si12_u;
  wire        need_si16;
  wire        need_si20;
  wire        need_si26;
  wire        src2_is_4;



  wire        rf_we;
  wire [ 4:0] rf_waddr;
  wire [31:0] rf_wdata;

  wire [31:0] alu_src1;
  wire [31:0] alu_src2;
  wire [31:0] alu_result;

  wire [31:0] mem_result;
  wire [31:0] final_result;


  assign op_31_26 = ds_inst[31:26];
  assign op_25_22 = ds_inst[25:22];
  assign op_21_20 = ds_inst[21:20];
  assign op_19_15 = ds_inst[19:15];

  assign rd = ds_inst[4:0];
  assign rj = ds_inst[9:5];
  assign rk = ds_inst[14:10];

  assign i12 = ds_inst[21:10];
  assign i20 = ds_inst[24:5];
  assign i16 = ds_inst[25:10];
  assign i26 = {ds_inst[9:0], ds_inst[25:10]};

  decoder_6_64 u_dec0 (
      .in (op_31_26),
      .out(op_31_26_d)
  );
  decoder_4_16 u_dec1 (
      .in (op_25_22),
      .out(op_25_22_d)
  );
  decoder_2_4 u_dec2 (
      .in (op_21_20),
      .out(op_21_20_d)
  );
  decoder_5_32 u_dec3 (
      .in (op_19_15),
      .out(op_19_15_d)
  );

  assign inst_add_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
  assign inst_sub_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
  assign inst_slt = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
  assign inst_slti = op_31_26_d[6'h00] & op_25_22_d[4'h8];
  assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
  assign inst_sltu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
  assign inst_nor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
  assign inst_and = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
  assign inst_or = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
  assign inst_xor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
  assign inst_andi = op_31_26_d[6'h00] & op_25_22_d[4'hd];
  assign inst_ori = op_31_26_d[6'h00] & op_25_22_d[4'he];
  assign inst_xori = op_31_26_d[6'h00] & op_25_22_d[4'hf];
  assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
  assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
  assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
  assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
  assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
  assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
  assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
  assign inst_ld_w = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
  assign inst_ld_b = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
  assign inst_ld_h = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
  assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
  assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
  assign inst_st_w = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
  assign inst_st_h = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
  assign inst_st_b = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
  assign inst_jirl = op_31_26_d[6'h13];
  assign inst_b = op_31_26_d[6'h14];
  assign inst_bl = op_31_26_d[6'h15];
  assign inst_beq = op_31_26_d[6'h16];
  assign inst_bne = op_31_26_d[6'h17];
  assign inst_blt = op_31_26_d[6'h18];
  assign inst_bge = op_31_26_d[6'h19];
  assign inst_bltu = op_31_26_d[6'h1a];
  assign inst_bgeu = op_31_26_d[6'h1b];
  assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];
  assign inst_pcaddu = op_31_26_d[6'h07] & ~ds_inst[25];
  assign inst_mul_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
  assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
  assign inst_mulhu_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
  assign inst_div_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
  assign inst_mod_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
  assign inst_divu_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
  assign inst_modu_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

  assign use_div = inst_div_w | inst_divu_w | inst_modu_w | inst_mod_w;
  assign use_mod = inst_mod_w | inst_modu_w;

  assign use_high = inst_mulh_w | inst_mulhu_w;
  assign use_mul = inst_mul_w | inst_mulhu_w | inst_mulh_w;
  assign is_unsigned = inst_mulhu_w | inst_divu_w | inst_modu_w | inst_ld_bu | inst_ld_hu;

  assign alu_op[0] = inst_add_w | inst_addi_w | 
                     inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | 
                     inst_st_w |inst_st_b|inst_st_h|
                     inst_jirl | inst_bl| inst_pcaddu;
  assign alu_op[1] = inst_sub_w | inst_beq | inst_bne;
  assign alu_op[2] = inst_slt | inst_slti | inst_blt | inst_bge;
  assign alu_op[3] = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
  assign alu_op[4] = inst_and | inst_andi;
  assign alu_op[5] = inst_nor;
  assign alu_op[6] = inst_or | inst_ori;
  assign alu_op[7] = inst_xor | inst_xori;
  assign alu_op[8] = inst_slli_w | inst_sll_w;
  assign alu_op[9] = inst_srli_w | inst_srl_w;
  assign alu_op[10] = inst_srai_w | inst_sra_w;
  assign alu_op[11] = inst_lu12i_w;

  assign need_ui5 = inst_slli_w | inst_srli_w | inst_srai_w;
  assign need_si12 = inst_addi_w | inst_ld_w |inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu| inst_st_w |inst_st_h| inst_st_b| inst_slti | inst_sltui;
  assign need_si12_u = inst_andi | inst_ori | inst_xori;
  assign need_si16 = inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
  assign need_si20 = inst_lu12i_w | inst_pcaddu;
  assign need_si26 = inst_b | inst_bl;
  assign src2_is_4 = inst_jirl | inst_bl;

  assign imm = need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? rkd_value                     :
             need_si26 ? {{6{i26[25]}},i26[25:0]}   :
             need_si16 ? {{16{i16[15]}},i16[15:0]}  :
             need_si12 ? {{20{i12[11]}}, i12[11:0]} : {{{20{1'b0}}, i12[11:0]}};

  assign br_offs = need_si26 ? {{4{i26[25]}}, i26[25:0], 2'b0} : {{14{i16[15]}}, i16[15:0], 2'b0};

  assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

  assign src_reg_is_rd = inst_beq | inst_bne|inst_blt|inst_bltu|inst_bge|inst_bgeu | inst_st_w | inst_st_b |inst_st_h;

  assign src1_is_pc = inst_jirl | inst_bl | inst_pcaddu;

  assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_h|
                       inst_ld_hu|
                       inst_ld_bu|
                       inst_st_w   |
                       inst_st_b |
                       inst_st_h |
                       inst_lu12i_w|
                       inst_slti|
                       inst_sltui|
                       inst_andi|
                       inst_ori|
                       inst_xori |
                       inst_pcaddu ;
  assign bit_width = inst_ld_w|inst_st_w ? 4'hf:
                     inst_ld_h | inst_ld_hu|inst_st_h ? 4'h3:
                     inst_ld_b | inst_ld_bu|inst_st_b ? 4'h1 : 4'h0;
  assign res_from_mem = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_hu | inst_ld_bu;
  assign dst_is_r1 = inst_bl;
  assign gr_we = ~inst_st_w &~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt &~inst_bltu & ~inst_bge &~inst_bgeu;
  assign mem_we = inst_st_w | inst_st_b | inst_st_h;
  assign dest = dst_is_r1 ? 5'd1 : rd;
  assign is_ls = |bit_width;
  assign rf_raddr1 = rj;
  assign rf_raddr2 = src_reg_is_rd ? rd : rk;



  assign rj_value = rf_rdata1;
  assign rkd_value = rf_rdata2;



  //跳转控制信号
  assign may_jump = (inst_beq || inst_bne ||inst_blt||inst_bge||inst_bltu||inst_bgeu|| inst_jirl || inst_bl || inst_b) ;
  assign use_rj_value = inst_jirl;
  assign use_less = inst_blt | inst_bltu | inst_bge | inst_bgeu;
  assign need_less = inst_blt | inst_bltu;

  assign use_zero = inst_beq || inst_bne;
  assign need_zero = inst_beq;


  assign {pc_is_jump, ds_inst, ds_pc} = fs_to_ds_bus;



  assign ds_to_es_bus = {
    alu_op,  // 12
    bit_width,  // 4

    may_jump,  // 1 
    use_rj_value,  // 1
    use_less,  // 1
    need_less,  // 1
    use_zero,  // 1
    need_zero,  // 1

    src1_is_pc,  // 1
    src2_is_imm,  // 1
    src2_is_4,  // 1
    gr_we,  // 1
    mem_we,  // 1
    dest,  // 5
    imm,  // 32

    rf_raddr1,  //5
    rf_raddr2,  //5

    rj_value,  // 32
    rkd_value,  // 32
    ds_pc,  // 32
    pc_is_jump,  //1
    res_from_mem,  //1

    use_mul,
    use_high,
    is_unsigned,
    use_div,
    use_mod
  };

  assign rg_en = gr_we;
  assign use_rkd = ~(src2_is_4 | src2_is_imm);
  assign use_rj = use_rj_value | ~src1_is_pc;
endmodule
module decoder_2_4(
    input  wire [ 1:0] in,
    output wire [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  wire [ 3:0] in,
    output wire [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  wire [ 4:0] in,
    output wire [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  wire [ 5:0] in,
    output wire [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule
