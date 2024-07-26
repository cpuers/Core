`include "define.vh"

module core_top (
    input  wire        aclk,
    input  wire        aresetn,
    /* verilator lint_off UNUSED */
    input  wire [ 7:0] intrpt,
    /* verilator lint_on UNUSED */
    //AXI interface 
    //read reqest
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,
    //read back
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    //write request
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,
    //write data
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    //write back
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready

    //debug
    `ifdef TEAMPACKAGE_EN
    ,
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata,
    output wire [31:0] debug1_wb_pc,
    output wire [ 3:0] debug1_wb_rf_wen,
    output wire [ 4:0] debug1_wb_rf_wnum,
    output wire [31:0] debug1_wb_rf_wdata
    `endif
);
  reg reset;
  always @(posedge aclk) reset <= ~aresetn;

  wire                           es_ready1;
  wire                           es_ready2;
  wire                           ws_ready;
  wire                           ds_to_es_valid1;
  wire                           ds_to_es_valid2;
  wire                     [1:0] es_to_ws_valid1;
  wire                     [1:0] es_to_ws_valid2;
  wire                     [13:0]csr_addr1;
  wire                     [13:0]csr_addr2;
  wire                      [31:0] csr_data1;
  wire                      [31:0] csr_data2;

  wire flush_IF1;
  wire flush_IF2;
  wire flush_ID1;
  wire flush_ID2;

  //wire [   `DS_TO_ES_BUS_WD-1:0] EXE_instr0;
  //wire [   `DS_TO_ES_BUS_WD-1:0] EXE_instr1;

  wire [  `DS_TO_ES_BUS_WD -1:0] ds_to_es_bus1;
  wire [  `DS_TO_ES_BUS_WD -1:0] ds_to_es_bus2;
  wire [   `FORWAED_BUS_WD -1:0] exm_forward_data1;
  wire [   `FORWAED_BUS_WD -1:0] exm_forward_data2;
  wire [        `BR_BUS_WD -1:0] br_bus1;
  wire [        `BR_BUS_WD -1:0] br_bus2;

  wire [  `ES_TO_WS_BUS_WD -1:0] es_to_ws_bus1;
  wire [  `ES_TO_WS_BUS_WD -1:0] es_to_ws_bus2;
  wire [  `WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
  wire                           es_nblock1;
  wire                           es_nblock2;

  wire                           if0_valid;
  wire                           if0_valid_to_if1;
  wire                           if1_ready;
  wire [`IF0_TO_IF1_BUS_WD -1:0] if0_if1_bus;
  wire                           need_jump;
  wire [                   31:0] jump_pc;


 
  wire [                   31:0] iaddr;
  wire                           icache_addr_ok;
  wire                           icache_data_ok;
  wire [      `FS_ICACHE_WD-1:0] icache_rdata;
  
  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus1;
  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus2;
  wire [`MS_TO_ES_BUS_WD-1:0] ms_to_es_bus;
  wire [`EXM_DCACHE_RD -1:0] dcache_rdata_bus;
  wire [`EXM_DCACHE_WD -1:0] dcache_wdata_bus;

  wire        dcache_valid; 
  wire        dcache_ready;
  wire        dcache_op;       // 0: read, 1: write
  wire [31:0] dcache_addr;
  wire        dcache_uncached;
  wire        dcache_rvalid;
  wire [31:0] dcache_rdata;
  wire [ 3:0] dcache_awstrb;
  wire [31:0] dcache_wdata;
  wire        dcache_cacop_en;
  wire [ 1:0] dcache_cacop_code; 
  wire [31:0] dcache_cacop_addr;

  wire           inst_rd_req     ;
  wire [ 2:0]    inst_rd_type    ;
  wire [31:0]    inst_rd_addr    ;
  wire           inst_rd_rdy     ;
  wire           inst_ret_valid  ;
  wire           inst_ret_last   ;
  wire [31:0]    inst_ret_data   ;
  wire           inst_wr_req     ;
  wire [ 2:0]    inst_wr_type    ;
  wire [31:0]    inst_wr_addr    ;
  wire [ 3:0]    inst_wr_wstrb   ;
  wire [127:0]   inst_wr_data    ;
  /* verilator lint_off UNUSED */
  wire           inst_wr_rdy     ;
  /* verilator lint_on UNUSED */

  assign {inst_wr_req, inst_wr_type, inst_wr_addr, 
    inst_wr_wstrb, inst_wr_data} = 0;

  wire           data_rd_req     ;
  wire [ 2:0]    data_rd_type    ;
  wire [31:0]    data_rd_addr    ;
  wire           data_rd_rdy     ;
  wire           data_ret_valid  ;
  wire           data_ret_last   ;
  wire [31:0]    data_ret_data   ;
  wire           data_wr_req     ;
  wire [ 2:0]    data_wr_type    ;
  wire [31:0]    data_wr_addr    ;
  wire [ 3:0]    data_wr_wstrb   ;
  wire [127:0]   data_wr_data    ;
  wire           data_wr_rdy     ;

  assign dcache_rdata_bus = {dcache_ready, dcache_rvalid, dcache_rdata};

  assign {dcache_valid, dcache_op, dcache_addr, dcache_uncached, dcache_awstrb, dcache_wdata, 
          dcache_cacop_en, dcache_cacop_code, dcache_cacop_addr} = dcache_wdata_bus;
  assign need_jump = (br_bus1[32]) ? br_bus1[32] : (br_bus2[32]) ? br_bus2[32] : 1'b0;
  assign jump_pc = (br_bus1[32]) ? br_bus1[31:0] : (br_bus2[32]) ? br_bus2[31:0] : 32'b0;
  
  wire [  4*`IB_DATA_BUS_WD-1:0] if1_to_ib;
  wire [       `IB_WIDTH_LOG2:0] can_push_size;
  wire [                    2:0] push_num;
  wire [                   31:0] if0_pc;
  wire [                   31:0]                        pbu_next_pc;
  wire [                    3:0] pbu_pc_is_jump;
  wire [                    3:0] pbu_pc_valid;
  wire [    `IB_DATA_BUS_WD-1:0] IF_instr0;
  wire [    `IB_DATA_BUS_WD-1:0] IF_instr1;
  wire                           IF_instr0_valid;
  wire                           IF_instr1_valid;

  wire [                    4:0] read_addr0;
  wire [                    4:0] read_addr1;
  wire [                    4:0] read_addr2;
  wire [                    4:0] read_addr3;
  wire [                   31:0] read_data0;
  wire [                   31:0] read_data1;
  wire [                   31:0] read_data2;
  wire [                   31:0] read_data3;
  /* verilator lint_off UNUSED */
  wire [                   31:0] ws_pc1;
  wire [                   31:0] ws_pc2;
  /* verilator lint_on UNUSED */
  wire                           rf_we1;
  wire [                    4:0] rf_waddr1;  //36:32
  wire [                   31:0] rf_wdata1;  //31:0
  wire                           rf_we2;
  wire [                    4:0] rf_waddr2;  //36:32
  wire [                   31:0] rf_wdata2;
  wire iuncached;
  assign {ws_pc1, rf_we1, rf_waddr1, rf_wdata1, ws_pc2, rf_we2, rf_waddr2, rf_wdata2} = ws_to_rf_bus;
  wire [1:0] IB_pop_op;
  
  wire                   jump_excp_fail;
  wire [`CSR_BUS_WD-1:0] csr_bus1;
  wire [`CSR_BUS_WD-1:0] csr_bus2;
  wire                   csr_we;
  wire [           13:0] csr_addr;
  wire [           31:0] csr_wdata;

  BPU BPU (
      .pc(if0_pc),
      .next_pc(pbu_next_pc),
      .pc_is_jump(pbu_pc_is_jump),
      .pc_valid(pbu_pc_valid)
  );
  icache_dummy icache_dummy(
      .clock(aclk),
      .reset(reset),
  
      .valid(if0_valid),      // in cpu, valid no dep on ok;
      .ready(icache_addr_ok),    // in cache, addr_ok can dep on valid
      .araddr(iaddr),
      .uncached(iuncached),
  
      .rvalid(icache_data_ok),
      .rdata(icache_rdata),
      /* verilator lint_off PINCONNECTEMPTY */
      .rhit(           ),
  
      //TODO
      .cacop_valid(dcache_cacop_en),
      .cacop_ready(               ),
      /* verilator lint_on PINCONNECTEMPTY */
      .cacop_code(dcache_cacop_code), // code[4:3]
      .cacop_addr(dcache_cacop_addr),
      /* verilator lint_on UNUSED */
      
      // axi bridge
      .rd_req(inst_rd_req),
      .rd_type(inst_rd_type),
      .rd_addr(inst_rd_addr),
      .rd_rdy(inst_rd_rdy),
      .ret_valid(inst_ret_valid),
      .ret_last(inst_ret_last),
      .ret_data(inst_ret_data)
  );
  IF_stage0 IF_stage0 (
      .clk      (aclk),
      .flush_IF (flush_IF1 | flush_IF2),
      .rst      (reset),
      // jump_signal
      .need_jump(need_jump),
      .jump_pc  (jump_pc),
      //for cache
      .valid    (if0_valid),
      .iaddr    (iaddr),
      .uncached(iuncached),

      .addr_ok    (icache_addr_ok),
      //for IF1
      .if0_if1_bus(if0_if1_bus),
      .IF1_ready  (if1_ready),
      .IF0_valid (if0_valid_to_if1),
      //for BPU
      .pc_to_PBU  (if0_pc),
      .pc_is_jump (pbu_pc_is_jump),
      .pc_valid   (pbu_pc_valid),
      .pre_nextpc (pbu_next_pc)
  );
  IF_stage1 IF_stage1 (
      .clk(aclk),
      .rst(reset),
      .flush_IF(flush_IF1 | flush_IF2),
      .if0_if1_bus(if0_if1_bus),

      .if1_to_ib(if1_to_ib),
      .can_push_size(can_push_size),
      .push_num(push_num),
      .data_ok(icache_data_ok),
      .rdata(icache_rdata),
      .if0_valid(if0_valid_to_if1),
      .if1_ready(if1_ready)
  );
  InstrBuffer InstrBuffer (
      .clk(aclk),
      .rst(reset),
      .flush(flush_IF1 | flush_IF2),
      .if1_to_ib(if1_to_ib),
      .push_num(push_num),
      .pop_op(IB_pop_op),
      .if_bf_sz(can_push_size),
      .pop_instr0(IF_instr0),
      .instr0_valid(IF_instr0_valid),
      .pop_instr1(IF_instr1),
      .instr1_valid(IF_instr1_valid)

  );
  regfile regfile (
      .clock(~aclk),
      .reset(reset),
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
  csr my_csr (
    .clk(~aclk),
    .rst(reset),

    //for ID
    .csr_addr1(csr_addr1),
    .csr_data1(csr_data1),
    .csr_addr2(csr_addr2),
    .csr_data2(csr_data2),
    
    //TODO
    .csr_waddr(),
    .csr_wen(),
    .wdata(),

    //FOR EXE
    .csr_bus(),
    .jump_excp_fail(),

    .excp_jump(),
    .excp_pc()


);
  ID_stage ID_stage (
      .clk             (aclk),
      .rst             (reset),
      // for IF
      .IF_instr0       (IF_instr0),
      .IF_instr0_valid (IF_instr0_valid),
      .IF_instr1       (IF_instr1),
      .IF_instr1_valid (IF_instr1_valid),
      .IF_pop_op       (IB_pop_op),
      //for EXE
      .EXE_instr0      (ds_to_es_bus1),
      .EXE_instr1      (ds_to_es_bus2),
      .EXE_instr0_valid(ds_to_es_valid1),
      .EXE_instr1_valid(ds_to_es_valid2),
      .EXE_ready       (es_ready1 & es_ready2),
      .flush_ID        (flush_ID1 | flush_ID2),
      //for regfile
      .read_addr0      (read_addr0),
      .read_addr1      (read_addr1),
      .read_addr2      (read_addr2),
      .read_addr3      (read_addr3),
      .read_data0      (read_data0),
      .read_data1      (read_data1),
      .read_data2      (read_data2),
      .read_data3      (read_data3),
      .csr_num1(csr_addr1),
      .csr_num2(csr_addr2),
      .csr_data1(csr_data1),
      .csr_data2(csr_data2)

  );

  EXM_stage EXM_stage1 (
      .clk  (aclk),
      .reset(reset),

      .es_ready(es_ready1),
      .ds_to_es_valid(ds_to_es_valid1),
      .ds_to_es_bus  (ds_to_es_bus1),

      .ws_ready(ws_ready),
      .es_to_ws_valid(es_to_ws_valid1),
      .es_to_ws_bus  (es_to_ws_bus1),
      .nblock        (es_nblock1),

      .es_to_ms_bus   (es_to_ms_bus1),
      .ms_to_es_bus   (ms_to_es_bus),

      .forward_data1  (exm_forward_data1),
      .forward_data2  (exm_forward_data2),
      .exm_forward_bus(exm_forward_data1),

      .br_bus        (br_bus1),
      .flush_IF      (flush_IF1),
      .flush_ID      (flush_ID1),

      .csr_bus       (csr_bus1),
      .jump_excp_fail(jump_excp_fail)
  );
  EXM_stage EXM_stage2 (
      .clk  (aclk),
      .reset(reset),

      .es_ready(es_ready2),
      .ds_to_es_valid(ds_to_es_valid2),
      .ds_to_es_bus  (ds_to_es_bus2),
      
      .ws_ready(ws_ready),
      .es_to_ws_valid(es_to_ws_valid2),
      .es_to_ws_bus  (es_to_ws_bus2),
      .nblock        (es_nblock2),

      .es_to_ms_bus   (es_to_ms_bus2),
      .ms_to_es_bus   (ms_to_es_bus),

      .forward_data1  (exm_forward_data1),
      .forward_data2  (exm_forward_data2),
      .exm_forward_bus(exm_forward_data2),

      .br_bus        (br_bus2),
      .flush_IF      (flush_IF2),
      .flush_ID      (flush_ID2),

      .csr_bus       (csr_bus2),
      .jump_excp_fail(jump_excp_fail)
  );

  MEM_stage MEM_stage (
      .clk              (aclk),
      .reset            (reset),
      .es_to_ms_bus1    (es_to_ms_bus1),
      .es_to_ms_bus2    (es_to_ms_bus2),
      .ms_to_es_bus     (ms_to_es_bus),
      .dcache_rdata_bus (dcache_rdata_bus),
      .dcache_wdata_bus (dcache_wdata_bus)
  );

  WB_stage wb_stage (
      .clk            (~aclk),
      .reset          (reset),
      .ws_ready       (ws_ready),
      .es_to_ws_valid1(es_to_ws_valid1),
      .es_to_ws_valid2(es_to_ws_valid2),
      .es_to_ws_bus1  (es_to_ws_bus1),
      .es_to_ws_bus2  (es_to_ws_bus2),
      .nblock1        (es_nblock1),
      .nblock2        (es_nblock2),
      .ws_to_rf_bus   (ws_to_rf_bus),

      .csr_we         (csr_we),
      .csr_addr       (csr_addr),
      .csr_wdata      (csr_wdata)
  );
  
  `ifdef TEAMPACKAGE_EN
  assign debug0_wb_pc            = wb_stage.ws_pc1;
  assign debug0_wb_rf_wen        = wb_stage.debug1_gr_we;
  assign debug0_wb_rf_wnum       = wb_stage.rf_waddr1;
  assign debug0_wb_rf_wdata      = wb_stage.rf_wdata1;
  assign debug1_wb_pc            = wb_stage.ws_pc2;
  assign debug1_wb_rf_wen        = wb_stage.debug2_gr_we;
  assign debug1_wb_rf_wnum       = wb_stage.rf_waddr2;
  assign debug1_wb_rf_wdata      = wb_stage.rf_wdata2;
  `endif

  dcache_dummy_v2 dcache(
      .clock(aclk),
      .reset(reset),
  
      // cpu load / store
      /// common control (c) channel
      .valid(dcache_valid),
      .ready(dcache_ready),
      .op(dcache_op),         // 0: read, 1: write
      .addr(dcache_addr),
      .uncached(dcache_uncached),
      /// read data (r) channel
      .rvalid(dcache_rvalid),
      .rdata(dcache_rdata),
    /* verilator lint_off PINCONNECTEMPTY */
      .rhit(            ),
      /// write address (aw) channel
      .awstrb(dcache_awstrb),
      /// write data (w) channel
      .wdata(dcache_wdata),
      .whit(            ),
      .cacop_valid(dcache_cacop_en),
      .cacop_ready(                ),
    /* verilator lint_on PINCONNECTEMPTY */
      .cacop_code(dcache_cacop_code), // code[4:3]
      .cacop_addr(dcache_cacop_addr),
  
      // axi bridge
      .rd_req(data_rd_req),
      .rd_type(data_rd_type),
      .rd_addr(data_rd_addr),
      .rd_rdy(data_rd_rdy),
      .ret_valid(data_ret_valid),
      .ret_last(data_ret_last),
      .ret_data(data_ret_data),
      .wr_req(data_wr_req),
      .wr_type(data_wr_type),
      .wr_addr(data_wr_addr),
      .wr_wstrb(data_wr_wstrb),
      .wr_data(data_wr_data),
      .wr_rdy(data_wr_rdy)
  );  
  //regfile

  axi_bridge u_axi_bridge(
    .clk(aclk),
    .reset(reset),
    
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    .inst_rd_req     ( inst_rd_req    ),    
    .inst_rd_type    ( inst_rd_type   ),
    .inst_rd_addr    ( inst_rd_addr   ),
    .inst_rd_rdy     ( inst_rd_rdy    ),
    .inst_ret_valid  ( inst_ret_valid ),
    .inst_ret_last   ( inst_ret_last  ),
    .inst_ret_data   ( inst_ret_data  ),
    .inst_wr_req     ( inst_wr_req    ),
    .inst_wr_type    ( inst_wr_type   ),
    .inst_wr_addr    ( inst_wr_addr   ),
    .inst_wr_wstrb   ( inst_wr_wstrb  ),
    .inst_wr_data    ( inst_wr_data   ),
    .inst_wr_rdy     ( inst_wr_rdy    ),
    
    .data_rd_req     ( data_rd_req    ),
    .data_rd_type    ( data_rd_type   ),
    .data_rd_addr    ( data_rd_addr   ),
    .data_rd_rdy     ( data_rd_rdy    ),
    .data_ret_valid  ( data_ret_valid ),
    .data_ret_last   ( data_ret_last  ),
    .data_ret_data   ( data_ret_data  ),
    .data_wr_req     ( data_wr_req    ),
    .data_wr_type    ( data_wr_type   ),
    .data_wr_addr    ( data_wr_addr   ),
    .data_wr_wstrb   ( data_wr_wstrb  ),
    .data_wr_data    ( data_wr_data   ),
    .data_wr_rdy     ( data_wr_rdy    ),
    /* verilator lint_off PINCONNECTEMPTY */
    .write_buffer_empty () // ?
    /* verilator lint_off PINCONNECTEMPTY */
  );


endmodule
