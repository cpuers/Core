`include "define.vh"

module WB_stage(
    input  wire                     clk,
    input  wire                     reset,
    //for EXM
    output                          ws_ready,
    input  [                   1:0] es_to_ws_valid1,
    input  [                   1:0] es_to_ws_valid2,
    input  [`ES_TO_WS_BUS_WD - 1:0] es_to_ws_bus1,
    input  [`ES_TO_WS_BUS_WD - 1:0] es_to_ws_bus2,
    input                           nblock1,
    input                           nblock2,
    output [ `FORWAED_BUS_WD - 1:0] forward_data1,
    output [ `FORWAED_BUS_WD - 1:0] forward_data2,
    //for regfile
    output [`WS_TO_RF_BUS_WD - 1:0] ws_to_rf_bus,
    //for  csr
    output reg                      csr_we,
    output reg [13:0]               csr_addr,
    output reg [31:0]               csr_wdata

    `ifdef DIFFTEST_EN
    ,

    input  [`ES_WS_DEBUG_BUS_WD-1:0] es_to_ws_debug_bus1,
    output [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus1,
    input  [`ES_WS_DEBUG_BUS_WD-1:0] es_to_ws_debug_bus2,
    output [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus2
    `endif 

);

// reg         ws_valid;
// wire        ws_ready_go;
wire        csr_we1;
wire [13:0] csr_addr1;
wire [31:0] csr_wdata1;

wire        csr_we2;
wire [13:0] csr_addr2;
wire [31:0] csr_wdata2;

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
assign {//csr_rd1,
        csr_we1,
        csr_addr1,
        csr_wdata1,
        
        ws_gr_we1       ,  //69:69
        ws_dest1       ,  //68:64
        ws_final_result1,  //63:32
        ws_pc1             //31:0
       } = es_to_ws_bus1;
assign {//csr_rd2,
        csr_we2,
        csr_addr2,
        csr_wdata2,

        ws_gr_we2       ,  //69:69
        ws_dest2      ,  //68:64
        ws_final_result2,  //63:32
        ws_pc2             //31:0
       } = es_to_ws_bus2;

//assign ws_ready_go = 1'b1;
//assign ws_ready  = !ws_valid || ws_ready_go;
assign forward_data1 = {es_to_ws_valid1[0], es_to_ws_bus1[`ES_TO_WS_BUS_WD - 1:32]};
assign forward_data2 = {es_to_ws_valid2[0], es_to_ws_bus2[`ES_TO_WS_BUS_WD - 1:32]};

assign ws_ready = nblock1 && nblock2; // es_to_ws_valid1[1] & es_to_ws_valid2[1]; //nblock1 && nblock2; //1'b1;//(es_to_ws_valid1 && es_to_ws_valid2);

assign debug1_gr_we = ws_gr_we1 && es_to_ws_valid1[1] && es_to_ws_valid1[0];
assign rf_we1    = ws_gr_we1 && es_to_ws_valid1[1] && es_to_ws_valid1[0] && ~(~|(ws_dest1 ^ ws_dest2) && rf_we2);
assign rf_waddr1 = ws_dest1;
assign rf_wdata1 = ws_final_result1;

assign debug2_gr_we = ws_gr_we2 && es_to_ws_valid2[1] && es_to_ws_valid2[0];
assign rf_we2    = ws_gr_we2 &&  es_to_ws_valid2[1] && es_to_ws_valid2[0];
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

always @(*) begin
    if(csr_we1==1'b1) begin
        csr_we = csr_we1 && es_to_ws_valid1[1] && es_to_ws_valid1[0];
        csr_addr = csr_addr1;
        csr_wdata = csr_wdata1;
    end
    else if(csr_we2==1'b1) begin
        csr_we = csr_we2 && es_to_ws_valid1[1] && es_to_ws_valid1[0] && es_to_ws_valid2[1] && es_to_ws_valid2[0];
        csr_addr = csr_addr2;
        csr_wdata = csr_wdata2;
    end
    else begin
        {csr_we, csr_addr, csr_wdata} = 0;
    end
end

 `ifdef DIFFTEST_EN

  wire [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus_w1;
  reg  [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus_r1;
  wire [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus_w2;
  reg  [`WS_DEBUG_BUS_WD-1:0] ws_debug_bus_r2;
  
  wire        cmt_valid1;
  wire [31:0] cmt_pc1 ;
  wire [31:0] cmt_excp_pc1; 
  wire        cmt_valid2;
  wire [31:0] cmt_pc2 ;
  wire [31:0] cmt_excp_pc2; 

  assign cmt_valid1 = es_to_ws_valid1[1] & es_to_ws_valid1[0];
  assign cmt_valid2 = es_to_ws_valid2[1] & es_to_ws_valid2[0];
  assign cmt_pc1 = ws_pc1;
  assign cmt_excp_pc1 = ws_pc1;
  assign cmt_pc2 = ws_pc2;
  assign cmt_excp_pc2 = ws_pc2;
  assign ws_debug_bus_w1 = {cmt_valid1, cmt_pc1, cmt_excp_pc1, es_to_ws_debug_bus1};
  assign ws_debug_bus_w2 = {cmt_valid2, cmt_pc2, cmt_excp_pc2, es_to_ws_debug_bus2};

  always @(posedge clk ) 
  begin
    if (reset) begin
        ws_debug_bus_r1 <= `WS_DEBUG_BUS_WD'h0;
        ws_debug_bus_r2 <= `WS_DEBUG_BUS_WD'h0;  
    end
    else
    begin
        ws_debug_bus_r1 <= ws_debug_bus_w1;
        ws_debug_bus_r2 <= ws_debug_bus_w2;
    end  
  end
  assign ws_debug_bus1 = ws_debug_bus_r1;
  assign ws_debug_bus2 = ws_debug_bus_r2;
  `endif 

endmodule
