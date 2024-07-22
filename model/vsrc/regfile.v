`include "config.vh"

module regfile (
    input                        clock,
    /* verilator lint_off UNUSED */
    input                        reset,
    /* verilator lint_on UNUSED */
    input  [$clog2(`NR_REG)-1:0] rd1,rs1,rs2,
    input  [$clog2(`NR_REG)-1:0] rd2,rs3,rs4,
    input  [         `WIDTH-1:0] wdata1,
    input  [         `WIDTH-1:0] wdata2,
    input                        wen1,
    input                        wen2,
    output [         `WIDTH-1:0] rs1data,rs2data,rs3data,rs4data
);
  reg [`WIDTH-1:0] mem[`NR_REG-1:0];

  assign rs1data = (rs1 == 0) ? `WIDTH'b0 : mem[rs1];
  assign rs2data = (rs2 == 0) ? `WIDTH'b0 : mem[rs2];
  assign rs3data = (rs3 == 0) ? `WIDTH'b0 : mem[rs3];
  assign rs4data = (rs4 == 0) ? `WIDTH'b0 : mem[rs4];

  always @(posedge clock) begin
    if (wen1 && (rd1!=5'b0)) 
    begin
      mem[rd1] <= wdata1;
    end 
    else 
    begin

    end
    if (wen2 && (rd2!=5'b0)) 
    begin
      mem[rd2] <= wdata2;
    end 
    else 
    begin

    end
    mem[0] <= `WIDTH'b0;
  end
endmodule
