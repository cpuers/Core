`include "define.vh"

module WB_stage(
    input clk,
    input reset,
     
    output ws_allowin,

    input es_to_ws_valid1,
    input es_to_ws_valid2,
    input [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus1,
    input [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus2,

    output [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus
);

reg         ws_valid;
wire        ws_ready_go;

reg [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus_r1;
reg [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus_r2;

wire        ws_gr_we1;
wire [ 4:0] ws_dest1;
wire [31:0] ws_final_result1;
wire [31:0] ws_pc1;

wire        ws_gr_we2;
wire [ 4:0] ws_dest2;
wire [31:0] ws_final_result2;
wire [31:0] ws_pc2;

wire        rf_we1;
wire [4 :0] rf_waddr1;
wire [31:0] rf_wdata1;

wire        rf_we2;
wire [4 :0] rf_waddr2;
wire [31:0] rf_wdata2;

assign {ws_gr_we1       ,  //69:69
        ws_dest1       ,  //68:64
        ws_final_result1,  //63:32
        ws_pc1             //31:0
       } = es_to_ws_bus_r1;
assign {ws_gr_we2       ,  //69:69
        ws_dest2      ,  //68:64
        ws_final_result2,  //63:32
        ws_pc2             //31:0
       } = es_to_ws_bus_r2;


assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= es_to_ws_valid1 & es_to_ws_valid2;
    end

    if (es_to_ws_valid1 && es_to_ws_valid2 && ws_allowin) begin
        es_to_ws_bus_r1 <= es_to_ws_bus1;
        es_to_ws_bus_r2 <= es_to_ws_bus2;
    end
end

assign rf_we1    = ws_gr_we1 && ws_valid;
assign rf_waddr1 = ws_dest1;
assign rf_wdata1 = ws_final_result1;

assign rf_we2    = ws_gr_we2 && ws_valid;
assign rf_waddr2 = ws_dest2;
assign rf_wdata2 = ws_final_result2;

assign ws_to_rf_bus = {rf_we1   ,  //37:37
                       rf_waddr1,  //36:32
                       rf_wdata1,   //31:0
                       rf_we2   ,  //37:37
                       rf_waddr2,  //36:32
                       rf_wdata2
                      };

endmodule
