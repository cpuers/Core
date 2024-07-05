`include "config.vh"

module regfile (
    input                           clock,
    /* verilator lint_off UNUSED */
    input                           reset,
    /* verilator lint_on UNUSED */
    input   [$clog2(`NR_REG)-1:0]   rd, rs1, rs2,
    input   [`WIDTH-1:0]            wdata,
    input                           wen,
    output  [`WIDTH-1:0]            rs1data, rs2data
);
    reg     [`WIDTH-1:0]            mem [`NR_REG-1:0];

    assign rs1data = (rs1 == 0) ? `WIDTH'b0 : mem[rs1];
    assign rs2data = (rs2 == 0) ? `WIDTH'b0 : mem[rs2];

    always @(posedge clock) begin
        if (wen) begin
            mem[rd] <= wdata;
        end
        mem[0] <= `WIDTH'b0;
    end
endmodule
