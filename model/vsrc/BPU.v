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
    input [`BPU_ES_BUS_WD-1:0] bpu_es_bus2
);
  reg [15:0] num_need;
  reg [15:0] num_fail;
  //assign next_pc = (pc + 31'd16) & 32'hfffffff0;
  //assign pc_is_jump = 4'b00;
  //assign pc_valid = 4'b1111;

  wire [31:0] es_pc1;
  wire may_jump1;
  wire need_jump1;
  wire pre_fail1;
  wire [31:0] right_target1;
  wire [1:0] jump_type1;
  
  wire [31:0] es_pc2;
  wire may_jump2;
  wire need_jump2;
  wire pre_fail2;
  wire [31:0] right_target2;
  wire [1:0] jump_type2;

  //reg [`BPU_NUM-1:0] ras_valid;
  reg                      bpu_valid [0:`BPU_SIZE-1];
  reg                      ras_valid [0:`RAS_SIZE-1];

  reg [`PHT_LINE_SIZE-1:0] pht [0:`BPU_SIZE-1];
  reg [`BTB_LINE_SIZE-1:0] btb [0:`BPU_SIZE-1];

  reg [`RAS_LINE_SIZE-1:0] ras [0:`RAS_SIZE-1];
  reg [`RAS_IDX_SIZE-1:0] num_ras1;
  reg [`RAS_IDX_SIZE-1:0] num_ras2;
  //reg [               1:0] group_jump [0:`BPU_SIZE-1];
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

  assign {es_pc1, may_jump1, need_jump1, pre_fail1, right_target1, jump_type1} = bpu_es_bus1;
  assign {es_pc2, may_jump2, need_jump2, pre_fail2, right_target2, jump_type2} = bpu_es_bus2;
  
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

  assign group_valid = (pc[3:2]==2'b00) ? 4'b1111 : (pc[3:2]==2'b01) ? 4'b1110 : (pc[3:2]==2'b10) ? 4'b1100 : 4'b1000;
  //fs read 
  always @(*) begin
    if(num_ras1==0) num_ras2 = 0;
    
    if(group_valid[0] && bpu_valid[ridx1] && pht[ridx1] >=2'b10 && btb[ridx1][`BTB_TAG]==rtag) begin
      if(btb[ridx1][`BTB_TYPE]==2'b10) begin
        next_pc = {ras[num_ras1-num_ras2],2'b0};
        num_ras2 = num_ras2 + `RAS_IDX_SIZE'b1;
      end
      else begin
        next_pc = {btb[ridx1][`BTB_TARGET],2'b0};
      end
      pc_valid = 4'b0001 & group_valid;
      pc_is_jump = 4'b0001;
    end
    else if(group_valid[1] && bpu_valid[ridx2] && pht[ridx2] >=2'b10 && btb[ridx2][`BTB_TAG]==rtag) begin
      if(btb[ridx2][`BTB_TYPE]==2'b10) begin
        next_pc = {ras[num_ras1-num_ras2],2'b0};
        num_ras2 = num_ras2 + `RAS_IDX_SIZE'b1;
      end
      else begin
        next_pc = {btb[ridx2][`BTB_TARGET],2'b0};
      end
      pc_valid = 4'b0011 & group_valid;
      pc_is_jump = 4'b0010;
    end
    else if(group_valid[2] && bpu_valid[ridx3] && pht[ridx3] >=2'b10 && btb[ridx3][`BTB_TAG]==rtag) begin
      if(btb[ridx3][`BTB_TYPE]==2'b10) begin
        next_pc = {ras[num_ras1-num_ras2],2'b0};
        num_ras2 = num_ras2 + `RAS_IDX_SIZE'b1;
      end
      else begin
        next_pc = {btb[ridx3][`BTB_TARGET],2'b0};
      end
      pc_valid = 4'b0111 & group_valid;
      pc_is_jump = 4'b0100;
    end
    else if(group_valid[3] && bpu_valid[ridx4] && pht[ridx4] >=2'b10 && btb[ridx4][`BTB_TAG]==rtag) begin
      if(btb[ridx4][`BTB_TYPE]==2'b10) begin
        next_pc = {ras[num_ras1-num_ras2],2'b0};
        num_ras2 = num_ras2 + `RAS_IDX_SIZE'b1;
      end
      else begin
        next_pc = {btb[ridx4][`BTB_TARGET],2'b0};
      end
      pc_valid = 4'b1111 & group_valid;
      pc_is_jump = 4'b1000;
    end
    else begin
      next_pc = (pc + 31'd16) & 32'hfffffff0;
      pc_valid = 4'b1111;
      pc_is_jump = 4'b0000;
    end

    // if(bpu_valid[ridx]==1'b1 && group_valid[group_jump[ridx]] && pht[ridx] >= 2'b10 && btb[ridx][`BTB_TAG]==rtag) begin
    //   next_pc = {btb[ridx][`BTB_TARGET],2'b0};
    //   if(group_jump[ridx]==2'b00) begin
    //     pc_valid = 4'b0001 & group_valid;
    //     pc_is_jump = 4'b0001;
    //   end
    //   else if(group_jump[ridx]==2'b01) begin
    //     pc_valid = 4'b0011 & group_valid;
    //     pc_is_jump = 4'b0010;
    //   end
    //   else if(group_jump[ridx]==2'b10) begin
    //     pc_valid = 4'b0111 & group_valid;
    //     pc_is_jump = 4'b0100;
    //   end
    //   else begin
    //     pc_valid = 4'b1111 & group_valid;
    //     pc_is_jump = 4'b1000;
    //   end
    // end
    // else begin
    //   next_pc = (pc + 31'd16) & 32'hfffffff0;
    //   pc_valid = 4'b1111;
    //   pc_is_jump = 4'b0000;
    // end
  end

  //es write
  integer i;
  always @(posedge clk) begin
    if(reset) 
    begin
      for (i = 0; i < `BPU_SIZE; i = i + 1) begin
          bpu_valid[i] = 1'b0;
      end
      for (i = 0; i < `RAS_SIZE; i = i + 1) begin
          ras_valid[i] = 1'b0;
      end
      num_ras1 <= 0;
      num_need <= 0;
      num_fail <= 0;
    end
    else 
    begin
      if((!bpu_valid[widx1] || (bpu_valid[widx1] && btb[widx1][`BTB_TAG]!=wtag1))&& may_jump1 && need_jump1) begin
        bpu_valid[widx1] <= 1'b1;
        pht[widx1] <= 2'b10;
        btb[widx1] <= {jump_type1, wtag1, right_target1[31:2]};
        //group_jump[widx1] <= es_pc1[3:2];
        if(jump_type1[0]) begin
          ras[num_ras1-num_ras2] <= right_target1[31:2] + 30'b1;
          num_ras1 <= num_ras1 + `RAS_IDX_SIZE'b1;
        end
      end
      else if(bpu_valid[widx1] && may_jump1) begin
        if(need_jump1) begin
          pht[widx1] <= (pht[widx1]==2'b11) ? 2'b11 : pht[widx1] + 2'b01;
          btb[widx1] <= {jump_type1, wtag1, right_target1[31:2]};
          //group_jump[widx1] <= es_pc1[3:2];
        end
        else if (!need_jump1)begin
          pht[widx1] <= (pht[widx1]==2'b00) ? 2'b00 : pht[widx1] - 2'b01;
        end
      end
      else begin
        pht[widx1] <= pht[widx1];
        btb[widx1] <= btb[widx1];
      end

      if((!bpu_valid[widx2] || (bpu_valid[widx2] && btb[widx2][`BTB_TAG]!=wtag2))&& may_jump2 && need_jump2) begin
        bpu_valid[widx2] <= 1'b1;
        pht[widx2] <= 2'b10;
        btb[widx2] <= {jump_type2, wtag2, right_target2[31:2]};
        //group_jump[widx2] <= es_pc2[3:2];
        if(jump_type2[0]) begin
          ras[num_ras1-num_ras2] <= right_target2[31:2] + 30'b1;
          num_ras1 <= num_ras1 + `RAS_IDX_SIZE'b1;
        end
      end
      else if(bpu_valid[widx2] && may_jump2) begin
        if(need_jump2) begin
          pht[widx2] <= (pht[widx2]==2'b11) ? 2'b11 : pht[widx2] + 2'b01;
          btb[widx2] <= {jump_type2, wtag2, right_target2[31:2]};
          //group_jump[widx2] <= es_pc2[3:2];
        end
        else if(!need_jump2)begin
          pht[widx2] <= (pht[widx2]==2'b00) ? 2'b00 : pht[widx2] - 2'b01;
        end
      end
      else begin
        pht[widx2] <= pht[widx2];
        btb[widx2] <= btb[widx2];
      end 
    end

    if(may_jump1 && need_jump1) begin
      num_need <= num_need + 16'b1;
    end
    if(may_jump2 && need_jump2) begin
      num_need <= num_need + 16'b1;
    end
    if(may_jump1 && pre_fail1) begin
      num_fail <= num_fail +16'b1;
    end
    if(may_jump2 && pre_fail2) begin
      num_fail <= num_fail +16'b1;
    end
    
  end



endmodule

