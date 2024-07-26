`include "define.vh"

module MEM_stage(
    input wire clk,
    input wire reset,

    input [`ES_TO_MS_BUS_WD-1 :0] es_to_ms_bus1,
    input [`ES_TO_MS_BUS_WD-1 :0] es_to_ms_bus2,
    output [`MS_TO_ES_BUS_WD -1:0] ms_to_es_bus,
    
    input [`EXM_DCACHE_RD -1:0] dcache_rdata_bus,
    output [`EXM_DCACHE_WD -1:0] dcache_wdata_bus
);
reg [31:0] mem_addr;
reg        is_unsigned;
reg        mem_we;
reg        mem_rd;
reg [3:0]  bit_width;
reg [31:0] wdata;
wire [31:0] mem_result;
wire        dcache_ok;
wire        excp_ale;

reg [31:0] ms_pc;

wire [31:0] mem_addr1;
wire        is_unsigned1;
wire        mem_we1;
wire        mem_rd1;
wire [3:0]  bit_width1;
wire [31:0] wdata1;
wire [31:0] pc1;

wire [31:0] mem_addr2;
wire        is_unsigned2;
wire        mem_we2;
wire        mem_rd2;
wire [3:0]  bit_width2;
wire [31:0] wdata2;
wire [31:0] pc2;

assign {mem_addr1, //32
        is_unsigned1,
        mem_we1,
        mem_rd1,
        bit_width1,
        wdata1,
        pc1
} = es_to_ms_bus1;
assign {mem_addr2, //32
        is_unsigned2,
        mem_we2,
        mem_rd2,
        bit_width2,
        wdata2,
        pc2
} = es_to_ms_bus2;

always @(*) begin
    if(mem_we1 || mem_rd1) begin
        mem_addr = mem_addr1;
        is_unsigned = is_unsigned1; 
        mem_we = mem_we1;
        mem_rd = mem_rd1;
        bit_width = bit_width1;
        wdata = wdata1;
        ms_pc = pc1;
    end
    else if(mem_we2 || mem_rd2) begin
        mem_addr = mem_addr2;
        is_unsigned = is_unsigned2; 
        mem_we = mem_we2;
        mem_rd = mem_rd2;
        bit_width = bit_width2;
        wdata = wdata2;
        ms_pc = pc2;
    end
    else begin
        {mem_addr, is_unsigned, mem_we, mem_rd, bit_width, wdata, ms_pc} = 0;
    end 
end

assign ms_to_es_bus = {excp_ale, dcache_ok, mem_result};

Agu u_agu(
    .clk                (clk),
    .reset              (reset),
    .mem_addr           (mem_addr),
    .is_unsigned        (is_unsigned),
    .mem_we             (mem_we),
    .bit_width          (bit_width),
    .mem_rd             (mem_rd),
    .wdata              (wdata),
    .mem_result         (mem_result),
    .dcache_ok          (dcache_ok),
    .dcache_rdata_bus   (dcache_rdata_bus),
    .dcache_wdata_bus   (dcache_wdata_bus),
    .excp_ale           (excp_ale)
);

endmodule