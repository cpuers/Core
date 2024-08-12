`include "define.vh"

module IF_stage0 (
    input clk,
    input flush_IF,
    input rst,
    // jump_signal

    input csr_datf,
    input need_jump,
    input [31:0] jump_pc,

    //for cache
    output        valid,
    output [31:0] iaddr,
    output uncached,

    input addr_ok,

    output [2:0]viaddrh,
    input [2:0]piaddrh,
    input iuncached,
    

    //for IF1
    output [`IF0_TO_IF1_BUS_WD -1:0] if0_if1_bus,
    input IF1_ready,
    output IF0_valid,
    //for BPU
    output [31:0] pc_to_PBU,
    input [3:0] pc_is_jump,
    input [3:0] pc_valid,
    input [31:0] pre_nextpc,
    output install


);
    assign uncached = 1'b0;
    wire IF0_valid_w;
    assign IF0_valid_w = addr_ok;
  reg  [31:0] pc_r;
  wire [31:0] fs_pc;
  assign fs_pc = pc_r;
  assign iaddr = {piaddrh,fs_pc[28:0]};
  assign viaddrh = fs_pc[31:29];
  assign pc_to_PBU = fs_pc;
  reg IF0_valid_r;
  assign IF0_valid = IF0_valid_r;
  wire [`IF0_TO_IF1_BUS_WD-1:0] if0_to_if1_w;


  //TODO
  wire is_ADEF;
  wire in_excp;
  wire [5:0] excp_Ecode;
  wire [8:0] excp_subEcode;
  assign is_ADEF = |fs_pc[1:0];
  assign in_excp = is_ADEF;
  assign excp_Ecode = 6'h8;
  assign excp_subEcode = 9'b0;
  assign install =!IF1_ready||!addr_ok;

  assign if0_to_if1_w = {in_excp,excp_Ecode,excp_subEcode, pc_valid, pc_is_jump, fs_pc};
  assign valid = ~rst& IF1_ready & ~is_ADEF;
  always @(posedge clk) begin
    if (rst) begin
      pc_r <= 32'h1c000000;
    end else if (need_jump) begin
      pc_r <= jump_pc;
    end else if (install) begin
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
      IF0_valid_r <= 1'b0;
    end else if (!addr_ok&&!IF1_ready) begin
      if0_to_if1_r <= if0_to_if1_r;
      IF0_valid_r <= IF0_valid_r;
    end else begin
      if0_to_if1_r <= if0_to_if1_w;
      IF0_valid_r <= IF0_valid_w;
    end
  end
  assign if0_if1_bus = if0_to_if1_r;

endmodule
