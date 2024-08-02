// TODO
`include "define.vh"
`include "bpu.vh"
module BPU (
    input clk,
    input reset,
    //if
    input  [31:0] pc,
    output reg [31:0] next_pc,
    output reg [ 3:0] pc_is_jump,
    output reg [ 3:0] pc_valid,
    //exe
    input [`BPU_ES_BUS_WD-1:0] bpu_es_bus1,
    input [`BPU_ES_BUS_WD-1:0] bpu_es_bus2,

    output bpu_flush,
    output [31:0] bpu_jump_pc
);
  reg [15:0] num_need;
  reg [15:0] num_succ;
  //assign next_pc = (pc + 31'd16) & 32'hfffffff0;
  //assign pc_is_jump = 4'b00;
  //assign pc_valid = 4'b1111;

  wire in_excp1;
  wire is_etrn1;
  wire [31:0] es_pc1;
  wire may_jump1;
  wire need_jump1;
  wire pre_fail1;
  wire [31:0] right_target1;
  wire [1:0] jump_type1;
  
  wire in_excp2;
  wire is_etrn2;
  wire [31:0] es_pc2;
  wire may_jump2;
  wire need_jump2;
  wire pre_fail2;
  wire [31:0] right_target2;
  wire [1:0] jump_type2;
  wire flush1;
  wire flush2;
  wire flush;

  //reg [`BPU_NUM-1:0] ras_valid;
  reg                      bpu_valid [0:`BPU_SIZE-1];
  reg [`PHT_LINE_SIZE-1:0] pht [0:`BPU_SIZE-1];
  reg [`BTB_LINE_SIZE-1:0] btb [0:`BPU_SIZE-1];

  reg [`RAS_LINE_SIZE-1:0] ras [0:`RAS_SIZE-1];
  reg [`RAS_IDX_SIZE-1:0] num_ras;
  reg pop;
  reg pop_r;
  reg push;
  reg push_r;

  wire bpu_flush1;
  wire bpu_flush2;

  wire [`BPU_IDX_SZIE-1:0] ridx;
  wire [`BPU_IDX_SZIE-1:0] ridx1;  
  wire [`BPU_IDX_SZIE-1:0] ridx2;  
  wire [`BPU_IDX_SZIE-1:0] ridx3;  
  wire [`BPU_IDX_SZIE-1:0] ridx4;  
  wire [`BPU_TAG_SIZE-1:0] rtag;
  wire [3:0] group_valid;

  wire [`BPU_IDX_SZIE-1:0] widx1;  
  wire [`BPU_TAG_SIZE-1:0] wtag1;
  wire [`BPU_IDX_SZIE-1:0] widx2;  
  wire [`BPU_TAG_SIZE-1:0] wtag2;

  // reg [31:0] debug_pc1;
  // reg [31:0] debug_pc2;
  // reg f1;
  // reg f2;
  wire jump_valid1;
  wire jump_valid2;

  reg [`QUEUE_LINE_SIZE-1:0] jump_history [0:`QUEUE_SZIE-1];
  reg [`QUEUE_IDX_SZIE-1:0] qtop;
  reg [`QUEUE_IDX_SZIE-1:0] qtail;

  assign {flush1, in_excp1, is_etrn1, es_pc1, may_jump1, need_jump1, pre_fail1, right_target1, jump_type1} = bpu_es_bus1;
  assign {flush2, in_excp2, is_etrn2, es_pc2, may_jump2, need_jump2, pre_fail2, right_target2, jump_type2} = bpu_es_bus2;
  assign flush = flush1 | flush2;
  assign jump_valid1 = may_jump1 && !is_etrn1 && !in_excp1;
  assign jump_valid2 = may_jump2 && !is_etrn2 && !in_excp2;
  
  assign ridx = pc[`BPU_LINE_IDX] & `BPU_IDX_SZIE'h1fc;  //1,1111,1100
  assign ridx1 = ridx;
  assign ridx2 = ridx + `BPU_IDX_SZIE'b01;
  assign ridx3 = ridx + `BPU_IDX_SZIE'b10;
  assign ridx4 = ridx + `BPU_IDX_SZIE'b11;
  assign rtag = pc[`BPU_LINE_TAG]; //same

  assign widx1 = es_pc1[`BPU_LINE_IDX];
  assign wtag1 = es_pc1[`BPU_LINE_TAG];
  assign widx2 = es_pc2[`BPU_LINE_IDX];
  assign wtag2 = es_pc2[`BPU_LINE_TAG];

  assign bpu_flush1 = jump_valid1 && need_jump1 && !pre_fail1 && bpu_valid[widx1] && right_target1[31:2]!=jump_history[qtop];  //btb[widx1][`BTB_TYPE]!=2'b10 && btb[widx1][`BTB_TAG]==wtag1 && right_target1[31:2]!=btb[widx1][`BTB_TARGET];
  assign bpu_flush2 = jump_valid2 && need_jump2 && !pre_fail2 && bpu_valid[widx2] && right_target2[31:2]!=jump_history[qtop];  //btb[widx2][`BTB_TYPE]!=2'b10 && btb[widx2][`BTB_TAG]==wtag2 && right_target2[31:2]!=btb[widx2][`BTB_TARGET];
  assign bpu_flush = bpu_flush1 | bpu_flush2;
  assign bpu_jump_pc = bpu_flush1 ? right_target1 : right_target2;

  assign group_valid = (pc[3:2]==2'b00) ? 4'b1111 : (pc[3:2]==2'b01) ? 4'b1110 : (pc[3:2]==2'b10) ? 4'b1100 : 4'b1000;
  
  //fs read 
  always @(*) begin
    if(group_valid[0] && bpu_valid[ridx1] && pht[ridx1] >=2'b10 && btb[ridx1][`BTB_TAG]==rtag) 
    begin
      if(btb[ridx1][`BTB_TYPE]==2'b10) 
      begin
        next_pc = {ras[num_ras - `RAS_IDX_SIZE'b1],2'b0};
        //pop = 1'b1;
        //push = 1'b0;
      end
      else 
      begin
        next_pc = {btb[ridx1][`BTB_TARGET],2'b0};
        //pop = 1'b0;
        // if(btb[ridx1][`BTB_TYPE]==2'b01) begin
        //   ras[num_ras] = pc[31:2]&30'h3ffffffc + 30'h1;
        //   push = 1'b1;
        // end
        // else begin
        //   push = 1'b0;
        // end
      end
      pc_valid = 4'b0001 & group_valid;
      pc_is_jump = 4'b0001;
    end
    else if(group_valid[1] && bpu_valid[ridx2] && pht[ridx2] >=2'b10 && btb[ridx2][`BTB_TAG]==rtag) 
    begin
      if(btb[ridx2][`BTB_TYPE]==2'b10) 
      begin
        next_pc = {ras[num_ras - `RAS_IDX_SIZE'b1],2'b0};
        //pop = 1'b1;
        //push = 1'b0;
      end
      else 
      begin
        next_pc = {btb[ridx2][`BTB_TARGET],2'b0};
        //pop = 1'b0;
        // if(btb[ridx2][`BTB_TYPE]==2'b01) begin
        //   ras[num_ras] = pc[31:2]&30'h3ffffffc + 30'h2;
        //   push = 1'b1;
        // end
        // else begin
        //   push = 1'b0;
        // end
      end
      pc_valid = 4'b0011 & group_valid;
      pc_is_jump = 4'b0010;
    end
    else if(group_valid[2] && bpu_valid[ridx3] && pht[ridx3] >=2'b10 && btb[ridx3][`BTB_TAG]==rtag) 
    begin
      if(btb[ridx3][`BTB_TYPE]==2'b10) 
      begin
        next_pc = {ras[num_ras - `RAS_IDX_SIZE'b1],2'b0};
        //pop = 1'b1;
        //push = 1'b0;
      end
      else 
      begin
        next_pc = {btb[ridx3][`BTB_TARGET],2'b0};
        //pop = 1'b0;
        // if(btb[ridx3][`BTB_TYPE]==2'b01) begin
        //   ras[num_ras] = pc[31:2]&30'h3ffffffc + 30'h3;
        //   push = 1'b1;
        // end
        // else begin
        //   push = 1'b0;
        // end
      end
      pc_valid = 4'b0111 & group_valid;
      pc_is_jump = 4'b0100;
    end
    else if(group_valid[3] && bpu_valid[ridx4] && pht[ridx4] >=2'b10 && btb[ridx4][`BTB_TAG]==rtag) 
    begin
      if(btb[ridx4][`BTB_TYPE]==2'b10) 
      begin
        next_pc = {ras[num_ras - `RAS_IDX_SIZE'b1],2'b0};
        //pop = 1'b1;
        //push = 1'b0;
      end
      else 
      begin
        next_pc = {btb[ridx4][`BTB_TARGET],2'b0};
        //pop = 1'b0;
        // if(btb[ridx4][`BTB_TYPE]==2'b01) begin
        //   ras[num_ras] = pc[31:2]&30'h3ffffffc + 30'h4;
        //   push = 1'b1;
        // end
        // else begin
        //   push = 1'b0;
        // end
      end
      pc_valid = 4'b1111 & group_valid;
      pc_is_jump = 4'b1000;
    end
    else 
    begin
      next_pc = (pc + 31'd16) & 32'hfffffff0;
      pc_valid = group_valid;
      pc_is_jump = 4'b0000;
      //pop = 1'b0;
      push = 1'b0;
    end

    if(|pc_is_jump) begin
      jump_history[qtail] = next_pc[31:2];
      push = 1'b1;
    end
    else begin
      push =1 'b0;
    end
    if(jump_valid1 && need_jump1 && !pre_fail1 && bpu_valid[widx1] || jump_valid2 && need_jump2 && !pre_fail2 && bpu_valid[widx2]) begin
      pop = 1'b1;
    end
    else begin
      pop = 1'b0;
    end
  end

  //es write
  integer i;
  always @(posedge clk) begin
    if(reset) 
    begin
      for (i = 0; i < `BPU_SIZE; i = i + 1) 
      begin
          bpu_valid[i] = 1'b0;
      end
      num_ras <= 0;
      num_need <= 0;
      num_succ <= 0;
      pop_r <= 0;
      push_r <= 0;
      qtop <= 0;
      qtail <= 0;
    end
    else 
    begin
      pop_r <= pop;
      if(!pop && pop_r) begin
        //num_ras <= num_ras - `RAS_IDX_SIZE'b1;
        if(qtop == 4'b1111) begin
          qtop <= 0;
        end else begin
          qtop <= qtop + `QUEUE_IDX_SZIE'b1;
        end
      end
      push_r <= push;
      if(!push && push_r) begin
        //num_ras <= num_ras + `RAS_IDX_SIZE'b1;
        if(qtail == 4'b1111) begin
          qtail <= 0;
        end else begin
          qtail <= qtail + `QUEUE_IDX_SZIE'b1;
        end
      end

      if(jump_valid1 && need_jump1 && (!bpu_valid[widx1] || (bpu_valid[widx1] && btb[widx1][`BTB_TAG]!=wtag1))) 
      begin
        bpu_valid[widx1] <= 1'b1;
        pht[widx1] <= 2'b10;
        btb[widx1] <= {jump_type1, wtag1, right_target1[31:2]};
        // if(jump_type1 == 2'b01) begin
        //   ras[num_ras] <= es_pc1[31:2] + 30'b1;
        //   num_ras <= num_ras + `RAS_IDX_SIZE'b1;
        // end
      end
      else if(jump_valid1 && bpu_valid[widx1]) 
      begin
        if(need_jump1) 
        begin
          pht[widx1] <= (pht[widx1]==2'b11) ? 2'b11 : pht[widx1] + 2'b01;
          btb[widx1] <= {jump_type1, wtag1, right_target1[31:2]};
        end
        else if (!need_jump1)
        begin
          pht[widx1] <= (pht[widx1]==2'b00) ? 2'b00 : pht[widx1] - 2'b01;
        end
      end
      else 
      begin
        pht[widx1] <= pht[widx1];
        btb[widx1] <= btb[widx1];
      end

      if(jump_valid1 && need_jump1 && !bpu_flush1)
      begin
        if(jump_type1==2'b01) //call(bl) push ras
        begin  
          ras[num_ras] <= es_pc1[31:2] + 30'b1;
          num_ras <= num_ras + `RAS_IDX_SIZE'b1;
        end
        else if(jump_type1==2'b10) //return(jirl) pop ras
        begin  
          num_ras <= num_ras - `RAS_IDX_SIZE'b1;
        end
      end

      if(jump_valid2 && need_jump2 && (!bpu_valid[widx2] || (bpu_valid[widx2] && btb[widx2][`BTB_TAG]!=wtag2))) 
      begin
        bpu_valid[widx2] <= 1'b1;
        pht[widx2] <= 2'b10;
        btb[widx2] <= {jump_type2, wtag2, right_target2[31:2]};
        // if(jump_type2 == 2'b01) begin
        //   ras[num_ras] <= es_pc2[31:2] + 30'b1;
        //   num_ras <= num_ras + `RAS_IDX_SIZE'b1;
        // end
      end
      else if(jump_valid2 && bpu_valid[widx2]) 
      begin
        if(need_jump2) 
        begin
          pht[widx2] <= (pht[widx2]==2'b11) ? 2'b11 : pht[widx2] + 2'b01;
          btb[widx2] <= {jump_type2, wtag2, right_target2[31:2]};
        end
        else if(!need_jump2)
        begin
          pht[widx2] <= (pht[widx2]==2'b00) ? 2'b00 : pht[widx2] - 2'b01;
        end
      end
      else 
      begin
        pht[widx2] <= pht[widx2];
        btb[widx2] <= btb[widx2];
      end 

      if(jump_valid2 && need_jump2 && !bpu_flush)
      begin 
        if(jump_type2==2'b01) 
        begin
          ras[num_ras] <= es_pc2[31:2] + 30'b1;
          num_ras <= num_ras + `RAS_IDX_SIZE'b1;
        end
        else if(jump_type2==2'b10) 
        begin
          num_ras <= num_ras - `RAS_IDX_SIZE'b1;
        end
      end

      if(jump_valid1) 
      begin
        num_need <= num_need + 16'b1;
      end
      if(jump_valid2) 
      begin
        num_need <= num_need + 16'b1;
      end
      if(jump_valid1 && !pre_fail1) 
      begin
        num_succ <= num_succ +16'b1;
      end
      if(jump_valid2 && !pre_fail2) 
      begin
        num_succ <= num_succ +16'b1;
      end
    
    end
  end
endmodule

