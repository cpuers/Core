`include "define.vh"

module WB_stage(
    /* verilator lint_off EOFNEWLINE */
    input  wire clk,
    input  wire reset,
    /* verilator lint_on EOFNEWLINE */
     
    output wire ws_ready,

    input  wire [1:0] es_to_ws_valid1,
    input  wire [1:0] es_to_ws_valid2,
    input  wire [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus1,
    input  wire [`ES_TO_WS_BUS_WD -1:0] es_to_ws_bus2,
    input nblock1,
    input nblock2,

    output wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus
);

// reg         ws_valid;
// wire        ws_ready_go;

wire        ws_gr_we1;
wire [ 4:0] ws_dest1;
wire [31:0] ws_final_result1;

wire [31:0] ws_pc1;
wire [31:0] ws_pc2;

wire        ws_gr_we2;
wire [ 4:0] ws_dest2;
wire [31:0] ws_final_result2;


wire        rf_we1;
wire [4 :0] rf_waddr1;
wire [31:0] rf_wdata1;

wire        rf_we2;
wire [4 :0] rf_waddr2;
wire [31:0] rf_wdata2;
/* verilator lint_off UNUSED */
wire debug1_gr_we;
wire debug2_gr_we;
/* verilator lint_on UNUSED */
assign {ws_gr_we1       ,  //69:69
        ws_dest1       ,  //68:64
        ws_final_result1,  //63:32
        ws_pc1             //31:0
       } = es_to_ws_bus1;
assign {ws_gr_we2       ,  //69:69
        ws_dest2      ,  //68:64
        ws_final_result2,  //63:32
        ws_pc2             //31:0
       } = es_to_ws_bus2;


//assign ws_ready_go = 1'b1;
//assign ws_ready  = !ws_valid || ws_ready_go;

assign ws_ready = nblock1 && nblock2; // es_to_ws_valid1[1] & es_to_ws_valid2[1]; //nblock1 && nblock2; //1'b1;//(es_to_ws_valid1 && es_to_ws_valid2);

assign debug1_gr_we = ws_gr_we1 && es_to_ws_valid1[1] && es_to_ws_valid1[0];
assign rf_we1    = ws_gr_we1 && es_to_ws_valid1[1] && es_to_ws_valid1[0] && ~(ws_dest1 == ws_dest2 && es_to_ws_valid2[1] && es_to_ws_valid2[0]);
assign rf_waddr1 = ws_dest1;
assign rf_wdata1 = ws_final_result1;

assign debug2_gr_we = ws_gr_we2 && es_to_ws_valid2[1] && es_to_ws_valid2[0];
assign rf_we2    = ws_gr_we2 && es_to_ws_valid2[1] && es_to_ws_valid2[0];
assign rf_waddr2 = ws_dest2;
assign rf_wdata2 = ws_final_result2;

assign ws_to_rf_bus = {ws_pc1,
                       rf_we1   ,  //37:37
                       rf_waddr1,  //36:32
                       rf_wdata1,   //31:0
                       ws_pc2,
                       rf_we2   ,  //37:37
                       rf_waddr2,  //36:32
                       rf_wdata2
                      };

endmodule
