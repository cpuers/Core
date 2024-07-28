// TODO
`include "define.vh"
module BPU (
    input clk,
    input reset,
    //if
    input  [31:0] pc,
    output reg [31:0] next_pc,
    output reg [ 3:0] pc_is_jump,
    output reg [ 3:0] pc_valid,
    //id
    input [`BPU_DS_BUS_WD-1:0] bpu_ds_bus1,
    input [`BPU_DS_BUS_WD-1:0] bpu_ds_bus2,
    //exe
    input [`BPU_ES_BUS_WD-1:0] bpu_es_bus1,
    input [`BPU_ES_BUS_WD-1:0] bpu_es_bus2
);
  //assign next_pc = (pc + 31'd16) & 32'hfffffff0;
  //assign pc_is_jump = 4'b00;
  //assign pc_valid = 4'b1111;
  wire [31:0] ds_pc1;
  wire may_jump1;
  //wire [31:0] jump_target1;
  wire [31:0] ds_pc2;
  wire may_jump2;
  //wire [31:0] jump_target2;

  wire [31:0] es_pc1;
  wire need_jump1;
  wire pre_fail1;
  wire [31:0] right_target1;
  wire [31:0] es_pc2;
  wire need_jump2;
  wire pre_fail2;
  wire [31:0] right_target2;

  reg [`BPU_NUM-1:0] bpu_valid;
  reg [`BPU_NUM-1:0] ras_valid;

  reg [ 1:0] pht [`BPU_NUM-1:0];
  reg [29:0] btb [`BPU_NUM-1:0];
  reg [ 3:0] group_jump [`BPU_NUM-1:0];

  wire  [ `BPU_IDX-1:0] bpu_idx;  //four pc idx in pht
  wire  [ 3:0] group_valid;
  wire [ `BPU_IDX-1:0] bpu_idx_d1;
  wire [ `BPU_IDX-1:0] bpu_idx_e1;
  wire [ `BPU_IDX-1:0] bpu_idx_d2;
  wire [ `BPU_IDX-1:0] bpu_idx_e2;

  assign {ds_pc1, may_jump1} = bpu_ds_bus1;
  assign {ds_pc2, may_jump2} = bpu_ds_bus2;
  assign {es_pc1, need_jump1, pre_fail1, right_target1} = bpu_es_bus1;
  assign {es_pc2, need_jump2, pre_fail2, right_target2} = bpu_es_bus2;

  hash_28to5 bank_pc(.in(pc[31:4]), .out(bpu_idx));
  hash_28to5 bank_ds1_pc(.in(ds_pc1[31:4]), .out(bpu_idx_d1));
  hash_28to5 bank_es1_pc(.in(es_pc1[31:4]), .out(bpu_idx_e1));
  hash_28to5 bank_ds2_pc(.in(ds_pc1[31:4]), .out(bpu_idx_d2));
  hash_28to5 bank_es2_pc(.in(es_pc1[31:4]), .out(bpu_idx_e2));

  assign group_valid = (pc[3:2]==2'b00) ? 4'b1111 : (pc[3:2]==2'b01) ? 4'b1110 : (pc[3:2]==2'b10) ? 4'b1100 : 4'b1000;
  //fs
  always @(*) begin
    if(bpu_valid[bpu_idx]==1'b1 && |(group_jump[bpu_idx] & group_valid)) begin
      next_pc = {btb[bpu_idx],2'b0};
      if(group_jump[bpu_idx][0]&group_valid[0] == 1'b1) begin
        pc_valid = 4'b0001;
        pc_is_jump = 4'b0001;
      end
      else if(group_jump[bpu_idx][1]&group_valid[1] == 1'b1) begin
        pc_valid = 4'b0011;
        pc_is_jump = 4'b0010;
      end
      else if(group_jump[bpu_idx][2]&group_valid[2] == 1'b1) begin
        pc_valid = 4'b0111;
        pc_is_jump = 4'b0100;
      end
      else begin
        pc_valid = 4'b1111;
        pc_is_jump = 4'b1000;
      end
    end
    else begin
      next_pc = (pc + 31'd16) & 32'hfffffff0;
      pc_valid = 4'b1111;
      pc_is_jump = 4'b0000;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      bpu_valid <= 0;
    end
    else if(bpu_valid[bpu_idx]==1'b0) begin
      bpu_valid[bpu_idx] <= 1'b1;
      group_jump[bpu_idx] <= 4'b0000;
      pht[bpu_idx] <= 2'b01;
      btb[bpu_idx] <= pc[31:2] + 30'b100;
    end
  end
  
  //ds
  always @(posedge clk) begin
    if(!may_jump1) begin
      bpu_valid[bpu_idx_d1] <= 1'b0;
      group_jump[bpu_idx_d1] <= 4'b0000;
    end
    else begin
      bpu_valid[bpu_idx_d1] <= 1'b1;
      group_jump[bpu_idx_d1] <= (ds_pc1[3:2]==2'b00) ? 4'b0001 : (ds_pc1[3:2]==2'b01) ? 4'b0010 : (ds_pc1[3:2]==2'b10) ? 4'b0100 :4'b1000;
    end

    if(!may_jump2) begin
      bpu_valid[bpu_idx_d2] <= 1'b0;
      group_jump[bpu_idx_d2] <= 4'b0000;
    end
    else begin
      bpu_valid[bpu_idx_d2] <= 1'b1;
      group_jump[bpu_idx_d2] <= (ds_pc2[3:2]==2'b00) ? 4'b0001 : (ds_pc2[3:2]==2'b01) ? 4'b0010 : (ds_pc2[3:2]==2'b10) ? 4'b0100 :4'b1000;
    end
  end

  //es
  always @(posedge clk) begin
    if(need_jump1 && pre_fail1) begin
      pht[bpu_idx_e1] <= (pht[bpu_idx_e1]==2'b11) ? 2'b11 : pht[bpu_idx_e1] + 2'b01;
      btb[bpu_idx_e1] <= right_target1[31:2];
    end
    else if(!need_jump1 && pre_fail1)begin
      pht[bpu_idx_e1] <= (pht[bpu_idx_e1]==2'b00) ? 2'b00 : pht[bpu_idx_e1] - 2'b01;
      btb[bpu_idx_e1] <= right_target1[31:2];
    end
    else begin
      ;
    end

    if(need_jump2 && pre_fail2) begin
      pht[bpu_idx_e2] <= (pht[bpu_idx_e2]==2'b11) ? 2'b11 : pht[bpu_idx_e2] + 2'b01;
      btb[bpu_idx_e2] <= right_target2[31:2];
    end
    else if(!need_jump2 && pre_fail2)begin
      pht[bpu_idx_e2] <= (pht[bpu_idx_e2]==2'b00) ? 2'b00 : pht[bpu_idx_e2] - 2'b01;
      btb[bpu_idx_e2] <= right_target2[31:2];
    end
    else begin
      ;
    end
  end



endmodule

module hash_28to5 (
    input [27:0] in,
    output [4:0] out
);

    wire [4:0] temp1, temp2, temp3;

    assign temp1 = in[4:0] ^ in[9:5] ^ in[14:10];
    assign temp2 = in[19:15] ^ in[24:20] ^ in[27:23];
    assign temp3 = temp1 ^ temp2;

    assign out = temp3;

endmodule
