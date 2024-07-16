`include "define.v"

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
    output uncached,

    input addr_ok,

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
    end else if (!valid) begin
      if0_to_if1_r <= if0_to_if1_r;
    end else begin
      if0_to_if1_r <= if0_to_if1_w;
    end
  end
  assign if0_if1_bus = if0_to_if1_r;

endmodule
