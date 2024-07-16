// TODO
module BPU (
    input  [31:0] pc,
    output [31:0] next_pc,
    output  [ 3:0] pc_is_jump,
    output  [ 3:0] pc_valid
);
  assign next_pc = (pc + 31'd16) & 32'hfffffff0;
  assign pc_is_jump = 4'b00;
  assign pc_valid = 4'b1111;
endmodule
