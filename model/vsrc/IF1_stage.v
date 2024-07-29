`include "define.vh"
module IF_stage1 (
    input clk,
    input rst,
    input flush_IF,

    input [`IF0_TO_IF1_BUS_WD-1:0] if0_if1_bus,

    output [4*`IB_DATA_BUS_WD-1:0] if1_to_ib,
    input  [     `IB_WIDTH_LOG2:0] can_push_size,
    output [                  2:0] push_num,
    input                          data_ok,
    input  [    `FS_ICACHE_WD-1:0] rdata,
    input                          if0_valid,
    output reg                     if1_ready
);

  reg  [`IB_DATA_BUS_WD-1:0] store_buf[ 3:0];
  reg  [`IB_DATA_BUS_WD-1:0] instrs[ 3:0];
  reg is_watting;

  wire [ 3:0] pc_valid;
  wire [ 3:0] pc_is_jump;
  wire [31:0] fs_pc;
  wire [ 2:0] instr_num;
  assign {pc_valid, pc_is_jump, fs_pc} = if0_if1_bus;
  
  assign instr_num = {1'b0, ~fs_pc[3:2]} + 3'b1;
  reg [2:0] buf_num;
  reg buf_empty;
  wire can_push;
  /* verilator lint_off UNUSED */
  wire  [`IB_WIDTH_LOG2:0]total_size;
  
  assign total_size = {can_push_size + (buf_empty ? {2'b0, instr_num} : {2'b0, buf_num})};
  assign can_push   = ~total_size[`IB_WIDTH_LOG2];
  /* verilator lint_on  UNUSED */
  wire data_valid;
  assign data_valid =(if0_valid & data_ok) | (is_watting & data_ok);
  always @(*) begin
    case (instr_num)

      3'd1: begin
        instrs[0] = {pc_valid[3], pc_is_jump[3], fs_pc, rdata[127:96]};
        instrs[1] = {pc_valid[1], pc_is_jump[1], fs_pc + 4, rdata[63:32]};
        instrs[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        instrs[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      3'd2: begin
        instrs[0] = {pc_valid[2], pc_is_jump[2], fs_pc , rdata[95:64]};
        instrs[1] = {pc_valid[3], pc_is_jump[3], fs_pc + 4, rdata[127:96]};
        instrs[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        instrs[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      3'd3: begin
        instrs[0] = {pc_valid[1], pc_is_jump[1], fs_pc, rdata[63:32]};
        instrs[1] = {pc_valid[2], pc_is_jump[2], fs_pc + 4, rdata[95:64]};
        instrs[2] = {pc_valid[3], pc_is_jump[3], fs_pc + 8, rdata[127:96]};
        instrs[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
      default: begin
        instrs[0] = {pc_valid[0], pc_is_jump[0], fs_pc, rdata[31:0]};
        instrs[1] = {pc_valid[1], pc_is_jump[1], fs_pc + 4, rdata[63:32]};
        instrs[2] = {pc_valid[2], pc_is_jump[2], fs_pc + 8, rdata[95:64]};
        instrs[3] = {pc_valid[3], pc_is_jump[3], fs_pc + 12, rdata[127:96]};
      end
    endcase
  end

  always @(posedge clk) 
  begin
    if (rst | flush_IF) 
    begin
      is_watting <= 1'b0;
    end
    else if (if0_valid & !is_watting & !data_ok & buf_empty)
    begin
      is_watting <= 1'b1;
    end
    else if (is_watting & data_ok)
    begin
      is_watting <= 1'b0;
    end  
    else
    begin
      is_watting <= is_watting;
    end
  end

  always @(posedge clk) begin
    if (rst | flush_IF) begin
      buf_num   <= 3'b0;
      buf_empty <= 1'b1;
    end 
    else 
    begin
      if (!buf_empty) 
      begin
        if (can_push) 
        begin
          buf_empty <= 1'b1;
          buf_num   <= 3'b0;
        end 
        else 
        begin
          buf_empty <= buf_empty;
          buf_num   <= buf_num;
        end
      end 
      else 
      begin
        if (!can_push & data_valid) 
        begin
          buf_empty <= 1'b0;
          buf_num   <= instr_num;
          store_buf[0] <= instrs[0];
          store_buf[1] <= instrs[1];
          store_buf[2] <= instrs[2];
          store_buf[3] <= instrs[3];
        end 
        else 
        begin
          buf_empty <= buf_empty;
          buf_num   <= buf_num;
        end
      end
    end
  end

  always @(*) 
  begin
    if (rst| flush_IF)
    begin
      if1_ready = 1'b1;
    end
    if (buf_empty && !is_watting)
    begin
      if1_ready = !(if0_valid & !data_ok);
    end  
    else if(is_watting)
    begin
      if1_ready = can_push && data_ok;
    end
    else 
    begin
      if1_ready = can_push;
    end
  end
  assign push_num = rst ? 3'd0:  
         can_push ? (buf_empty ? instr_num &{3{data_valid}}: buf_num) : 3'd0;

  assign if1_to_ib[`IB_DATA_BUS_WD-1:0] = buf_empty? instrs[0]: store_buf[0];
  assign if1_to_ib[2*`IB_DATA_BUS_WD-1:`IB_DATA_BUS_WD] =buf_empty?instrs[1]:  store_buf[1];
  assign if1_to_ib[3*`IB_DATA_BUS_WD-1:2*`IB_DATA_BUS_WD] = buf_empty? instrs[2]: store_buf[2];

  assign if1_to_ib[4*`IB_DATA_BUS_WD-1:3*`IB_DATA_BUS_WD] = buf_empty? instrs[3]: store_buf[3];

endmodule
