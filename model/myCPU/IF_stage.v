`include "defines.v"

module IF_stage0 (
    input clk,
    input flush_IF,
    input rst,
    // jump_signal

    input need_jump,
    input [31:0] jump_pc,

    //for cache
    output        valid,
    output [31:0] iaddr,

    input                      addr_ok,

    //for IF1
    output [`IF0_TO_IF1_BUS_WD -1:0] if0_if1_bus,
    input IF1_ready,
    //for BPU
    output [31:0] pc_to_PBU,
    input [3:0] pc_is_jump,
    input [3:0] pc_valid,
    input [31:0] pre_nextpc


);

  reg  [31:0] pc_r;
  wire [31:0] fs_pc;
  assign fs_pc = pc_r;
  assign iaddr = fs_pc;
  wire [31:0] next_pc;
  assign pc_to_PBU = fs_pc;
  wire [`IF0_TO_IF1_BUS_WD-1:0] if0_to_if1_w;



  assign if0_to_if1_w = {pc_valid, pc_is_jump, fs_pc};
  assign valid = !IF1_ready || !addr_ok;
  always @(posedge clk) begin
    if (rst) begin
      pc_r <= 32'h1bfffffc;
    end else if (need_jump) begin
      pc_r <= jump_pc;
    end else if (!valid) begin
      pc_r <= pc_r;
    end else begin
      pc_r <= pre_nextpc;
    end
  end

  reg [`IF0_TO_IF1_BUS_WD-1:0] if0_to_if1_r;

  assign if0_if1_bus = if0_to_if1_r;

  always @(posedge clk) begin
    if (rst | flush_IF) begin
      if0_to_if1_r <= 0;
    end
    else if (!valid) 
    begin
        if0_to_if1_r <= if0_to_if1_r;    
    end 
    else 

    begin
      if0_to_if1_r <= if0_to_if1_w;
    end
  end
  assign if0_if1_bus = if0_to_if1_r;

endmodule
module IF_stage1 (
    input clk,
    input rst,
    input flush_IF,

    input [`IF0_TO_IF1_BUS_WD-1:0] if0_if1_bus,

    output [              3:0][`IB_DATA_BUS_WD-1:0] if1_to_ib,
    input  [ `IB_WIDTH_LOG2:0]                      can_push_size,
    output [              2:0]                      push_num,
    input                                           data_ok,
    input  [`FS_ICACHE_WD-1:0]                      rdata,
    input                                           if0_valid,
    output                                          if1_ready
);

  reg  [ 3:0] store_buf  [`IB_DATA_BUS_WD-1:0];

  wire [ 3:0] pc_valid;
  wire [ 3:0] pc_is_jump;
  wire [31:0] fs_pc;
  wire [ 2:0] instr_num;
  assign {pc_valid, pc_is_jump, fs_pc} = if0_if1_bus;

  assign instr_num = {1'b0, ~fs_pc[3:2]} + 3'b1;
  reg [2:0] buf_num;
  reg buf_empty;
  wire can_push;
  wire [`IB_WIDTH_LOG2:0] total_size;
  assign total_size = can_push_size + (buf_empty ? {2'b0, instr_num} : {2'b0, buf_num});
  assign can_push   = ~total_size[`IB_WIDTH_LOG2];

  reg [3:0] valid_instr[`IB_DATA_BUS_WD-1:0];
  always @(*) begin
    case (instr_num)

      3'd1: begin
        valid_instr[0] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
        valid_instr[1] = {pc_valid[1], pc_is_jump[1], fs_pc + 4, rdata[63:32]};
        valid_instr[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      3'd2: begin
        valid_instr[0] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[1] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
        valid_instr[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      3'd3: begin
        valid_instr[0] = {pc_valid[1], pc_is_jump[1], fs_pc + 4, rdata[63:32]};
        valid_instr[1] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      default: begin
        valid_instr[0] = {pc_valid[0], pc_is_jump[0], fs_pc, rdata[31:0]};
        valid_instr[1] = {pc_valid[1], pc_is_jump[1], fs_pc + 4, rdata[63:32]};
        valid_instr[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        valid_instr[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
    endcase
  end

  always @(posedge clk) begin
    if (rst | flush_IF) begin
      buf_num   <= 3'b0;
      buf_empty <= 1'b1;
    end else begin
      if (!buf_empty) begin
        if (data_ok & can_push) begin
          buf_empty <= 1'b1;
          buf_num   <= 3'b0;
        end else begin
          buf_empty <= buf_empty;
          buf_num   <= buf_num;
        end
      end else begin
        if (can_push) begin
          buf_empty <= 1'b1;
          buf_num   <= 3'b0;
        end else begin
          buf_empty <= buf_empty;
          buf_num   <= buf_num;
        end
      end
    end
  end

  assign if1_ready = buf_empty &(if0_valid & !data_ok);
  assign push_num = can_push ? (buf_empty ? instr_num : buf_num) : 3'd0;

  assign if1_to_ib[0] = valid_instr[0];
  assign if1_to_ib[1] = valid_instr[1];
  assign if1_to_ib[2] = valid_instr[2];

  assign if1_to_ib[3] = valid_instr[3];

endmodule
