`include "define.v"
`include "IF_stage.v"
module core_top #(
    parameter TLBNUM = 32
) (
    input         aclk,
    input         aresetn,
    input  [ 7:0] intrpt,
    //AXI interface 
    //read reqest
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    //read back
    input  [ 3:0] rid,
    input  [31:0] rdata,
    input  [ 1:0] rresp,
    input         rlast,
    input         rvalid,
    output        rready,
    //write request
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    //write data
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    //write back
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready,

    //debug
    input         break_point,
    input         infor_flag,
    input  [ 4:0] reg_num,
    output        ws_valid,
    output [31:0] rf_rdata,

    output [31:0] debug0_wb_pc,
    output [ 3:0] debug0_wb_rf_wen,
    output [ 4:0] debug0_wb_rf_wnum,
    output [31:0] debug0_wb_rf_wdata,
    output [31:0] debug0_wb_inst
);
  reg reset;
  always @(posedge aclk) reset <= ~aresetn;

  wire                           es_allowin1;
  wire                           es_allowin2;
  wire                           ws_allowin;
  wire                           ds_to_es_valid1;
  wire                           ds_to_es_valid2;
  wire                           es_to_ws_valid1;
  wire                           es_to_ws_valid2;

wire flush_IF;
wire flush_ID;

  wire [   `DS_TO_ES_BUS_WD-1:0] EXE_instr0;
  wire [   `DS_TO_ES_BUS_WD-1:0] EXE_instr1;

  wire [  `DS_TO_ES_BUS_WD -1:0] ds_to_es_bus1;
  wire [  `DS_TO_ES_BUS_WD -1:0] ds_to_es_bus2;
  wire [   `FORWAED_BUS_WD -1:0] exm_forward_data1;
  wire [   `FORWAED_BUS_WD -1:0] exm_forward_data2;
  wire [        `BR_BUS_WD -1:0] br_bus1;
  wire [        `BR_BUS_WD -1:0] br_bus2;

  wire [  `ES_TO_WS_BUS_WD -1:0] es_to_ws_bus1;
  wire [  `ES_TO_WS_BUS_WD -1:0] es_to_ws_bus2;
  wire [  `WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;

  wire                           if0_valid;
  wire                           if1_ready;
  wire [`IF0_TO_IF1_BUS_WD -1:0] if0_if1_bus;


  //FIX ME
  wire [                   31:0] iaddr;
  wire                           if_addr_ok;
  wire                           icache_data_ok;
  wire [      `FS_ICACHE_WD-1:0] icache_rdata;

  wire [  4*`IB_DATA_BUS_WD-1:0] if1_to_ib;
  wire [       `IB_WIDTH_LOG2:0] can_push_size;
  wire [                    2:0] push_num;
  wire [                   31:0] if0_pc;
  wire                           pbu_next_pc;
  wire [                    3:0] pbu_pc_is_jump;
  wire [                    3:0] pbu_pc_valid;
  wire [    `IB_DATA_BUS_WD-1:0] IF_instr0;
  wire [    `IB_DATA_BUS_WD-1:0] IF_instr1;
  wire                           IB_empty;

  wire [                    4:0] read_addr0;
  wire [                    4:0] read_addr1;
  wire [                    4:0] read_addr2;
  wire [                    4:0] read_addr3;
  wire [                   31:0] read_data0;
  wire [                   31:0] read_data1;
  wire [                   31:0] read_data2;
  wire [                   31:0] read_data3;
  wire                           rf_we1;
  wire [                    4:0] rf_waddr1;  //36:32
  wire [                   31:0] rf_wdata1;  //31:0
  wire                           rf_we2;
  wire [                    4:0] rf_waddr2;  //36:32
  wire [                   31:0] rf_wdata2;
  assign {rf_we1, rf_waddr1, rf_wdata1, rf_we2, rf_waddr2, rf_wdata2} = ws_to_rf_bus;
  wire [1:0] IB_pop_op;
  BPU BPU (
      .pc(if0_pc),
      .next_pc(pbu_next_pc),
      .pc_is_jump(pbu_pc_is_jump),
      .pc_valid(pbu_pc_valid)
  );
  IF_stage IF_stage (
      .clk      (clk),
      .flush_IF (flush_IF),
      .rst      (reset),
      // jump_signal
      .need_jump(),
      .jump_pc  (),
      //for cache
      .valid    (if0_valid),
      .iaddr    (iaddr),

      .addr_ok    (if_addr_ok),
      //for IF1
      .if0_if1_bus(if0_if1_bus),
      .IF1_ready  (if1_ready),
      //for BPU
      .pc_to_PBU  (if0_pc),
      .pc_is_jump (pbu_pc_is_jump),
      .pc_valid   (pbu_pc_valid),
      .pre_nextpc (pbu_next_pc)
  );
  IF_stage1 IF_stage1 (
      .clk(clk),
      .rst(reset),
      .flush_IF(flush_IF),
      .if0_if1_bus(if0_if1_bus),

      .if1_to_ib(if1_to_ib),
      .can_push_size(can_push_size),
      .push_num(push_num),
      .data_ok(icache_data_ok),
      .rdata(icache_rdata),
      .if0_valid(if0_valid),
      .if1_ready(if1_ready)
  );
  InstrBuffer InstrBuffer (
      .clk(clk),
      .rst(rst),
      .flush(flush_IF),
      .if1_to_ib(if1_to_ib),
      .push_num(push_num),
      .pop_op(IB_pop_op),
      .if_bf_sz(can_push_size),
      .empty(IB_empty),
      .pop_instr0(IF_instr0),
      .pop_instr1(IF_instr1)

  );
  regfile regfile (
      .clock(~clk),
      .reset(rst),
      .rd1(rf_waddr1),
      .rs1(read_addr0),
      .rs2(read_addr1),
      .rd2(rf_waddr2),
      .rs3(read_addr2),
      .rs4(read_addr3),
      .wdata1(rf_wdata1),
      .wdata2(rf_wdata2),
      .wen1(rf_we1),
      .wen2(rf_we2),
      .rs1data(read_data0),
      .rs2data(read_data1),
      .rs3data(read_data2),
      .rs4data(read_data3)
  );
  ID_stage ID_stage (
      .clk             (clk),
      .rst             (reset),
      // for IF
      .IF_instr0       (IF_instr0),
      .IF_instr1       (IF_instr1),
      .IB_empty        (IB_empty),
      .IF_pop_op       (IB_pop_op),
      //for EXE
      .EXE_instr0      (ds_to_es_bus1),
      .EXE_instr1      (ds_to_es_bus2),
      .EXE_instr0_valid(ds_to_es_valid1),
      .EXE_instr1_valid(ds_to_es_valid2),
      .EXE_ready       (es_allowin1 & es_allowin2),
      .flush_ID        (flush_ID),
      //for regfile
      .read_addr0      (read_addr0),
      .read_addr1      (read_addr1),
      .read_addr2      (read_addr2),
      .read_addr3      (read_addr3),
      .read_data0      (read_data0),
      .read_data1      (read_data1),
      .read_data2      (read_data2),
      .read_data3      (read_data3)

  );

  EXM_stage EXM_stage1 (
      .clk  (aclk),
      .reset(reset),

      .ws_allowin(ws_allowin),
      .es_allowin(es_allowin1),

      .ds_to_es_valid(ds_to_es_valid1),
      .ds_to_es_bus  (ds_to_es_bus1),

      .forward_data1  (exm_forward_data1),
      .forward_data2  (exm_forward_data2),
      .exm_forward_bus(exm_forward_data1),

      .br_bus        (br_bus1),
      .es_to_ws_valid(es_to_ws_valid1),
      .es_to_ws_bus  (es_to_ws_bus1),
      .flush_IF      (flush_IF),
      .flush_ID      (flush_ID)
  );
  EXM_stage EXM_stage2 (
      .clk  (aclk),
      .reset(reset),

      .ws_allowin(ws_allowin),
      .es_allowin(es_allowin2),

      .ds_to_es_valid(ds_to_es_valid2),
      .ds_to_es_bus  (ds_to_es_bus2),

      .forward_data1  (exm_forward_data1),
      .forward_data2  (exm_forward_data2),
      .exm_forward_bus(exm_forward_data2),

      .br_bus        (br_bus2),
      .es_to_ws_valid(es_to_ws_valid2),
      .es_to_ws_bus  (es_to_ws_bus2),
      .flush_IF      (flush_IF),
      .flush_ID      (flush_ID)
  );

  wb_stage wb_stage (
      .clk            (clk),
      .reset          (reset),
      .ws_allowin     (ws_allowin),
      .es_to_ws_valid1(es_to_ws_valid1),
      .es_to_ws_valid2(es_to_ws_valid2),
      .es_to_ws_bus1  (es_to_ws_bus1),
      .es_to_ws_bus2  (es_to_ws_bus2),
      .ws_to_rf_bus   (ws_to_rf_bus)
  );

  // icache_v1 Icache(
  //     .clock,
  //     .reset,

  //     .valid,
  //     .addr_ok,
  //     .addr,
  //     .data_ok,
  //     .rdata,

  //     .rd_req,
  //     .rd_type,
  //     .rd_addr,
  //     .rd_rdy,
  //     .ret_valid,
  //     .ret_data
  // );

  //dcache Dcache();
  //regfile

endmodule
