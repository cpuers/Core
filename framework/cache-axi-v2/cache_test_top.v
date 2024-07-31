// ┌────────┐   ┌────────┐
// | icache |   | dcache |
// └────┬───┘   └───┬────┘
//      │           │
//     ┌────────────┐
//     | axi_bridge | (Master)
//     └─────┬──────┘
//           │
//     ┌─────┴──────┐     
//     |  axi_ram   | (Slave)
//     └────────────┘


module cache_test_top (
    input  wire          clock,
    input  wire          reset,

    input  wire          i_valid,
    output wire          i_ready,
    input  wire  [31:0]  i_araddr,
    input  wire          i_uncached,
    output wire          i_rvalid,
    output wire [127:0]  i_rdata,
    output wire          i_rhit,
    input  wire          i_cacop_valid,
    output wire          i_cacop_ready,
    input  wire  [ 1:0]  i_cacop_code,
    input  wire  [31:0]  i_cacop_addr,

    input  wire          d_valid,
    output wire          d_ready,
    input  wire          d_op,
    input  wire  [31:0]  d_addr,
    input  wire  [ 3:0]  d_strb,
    input  wire          d_uncached,
    output wire          d_rvalid,
    output wire  [31:0]  d_rdata,
    output wire          d_rhit,
    input  wire  [31:0]  d_wdata,
    output wire          d_whit,
    input  wire          d_cacop_valid,
    output wire          d_cacop_ready,
    input  wire  [ 1:0]  d_cacop_code,
    input  wire  [31:0]  d_cacop_addr
);

    wire          i_rd_req   ;
    wire  [ 2:0]  i_rd_type  ;
    wire  [31:0]  i_rd_addr  ;
    wire          i_rd_rdy   ;
    wire          i_ret_valid;
    wire          i_ret_last ;
    wire  [31:0]  i_ret_data ;
    wire          d_rd_req   ;
    wire  [ 2:0]  d_rd_type  ;
    wire  [31:0]  d_rd_addr  ;
    wire          d_rd_rdy   ;
    wire          d_ret_valid;
    wire          d_ret_last ;
    wire  [31:0]  d_ret_data ;
    wire          d_wr_req   ;
    wire  [ 2:0]  d_wr_type  ;
    wire  [31:0]  d_wr_addr  ;
    wire  [ 3:0]  d_wr_wstrb ;
    wire [127:0]  d_wr_data  ;
    wire          d_wr_rdy   ;

    `ICACHE_MODULE u_icache(
        .clock      ( clock        ),
        .reset      ( reset        ),

        .valid      ( i_valid      ),
        .ready      ( i_ready      ),
        .araddr     ( i_araddr     ),
        .uncached   ( i_uncached   ),
        .rvalid     ( i_rvalid     ),
        .rdata      ( i_rdata      ),
        .rhit       ( i_rhit       ),
        .cacop_valid( i_cacop_valid),
        .cacop_ready( i_cacop_ready),
        .cacop_code ( i_cacop_code ),
        .cacop_addr ( i_cacop_addr ),

        .rd_req     ( i_rd_req     ),
        .rd_type    ( i_rd_type    ),
        .rd_addr    ( i_rd_addr    ),
        .rd_rdy     ( i_rd_rdy     ),
        .ret_valid  ( i_ret_valid  ),
        .ret_last   ( i_ret_last   ),
        .ret_data   ( i_ret_data   )
    );

    `DCACHE_MODULE u_dcache(
        .clock      ( clock        ),
        .reset      ( reset        ),

        .valid      ( d_valid      ),
        .ready      ( d_ready      ),
        .op         ( d_op         ),
        .addr       ( d_addr       ),
        .strb       ( d_strb       ),
        .uncached   ( d_uncached   ),
        .rvalid     ( d_rvalid     ),
        .rdata      ( d_rdata      ),
        .rhit       ( d_rhit       ),
        .wdata      ( d_wdata      ),
        .whit       ( d_whit       ),
        .cacop_valid( d_cacop_valid),
        .cacop_ready( d_cacop_ready),
        .cacop_code ( d_cacop_code ),
        .cacop_addr ( d_cacop_addr ),

        .rd_req     ( d_rd_req     ),
        .rd_type    ( d_rd_type    ),
        .rd_addr    ( d_rd_addr    ),
        .rd_rdy     ( d_rd_rdy     ),
        .ret_valid  ( d_ret_valid  ),
        .ret_last   ( d_ret_last   ),
        .ret_data   ( d_ret_data   ),
        .wr_req     ( d_wr_req     ),
        .wr_type    ( d_wr_type    ),
        .wr_addr    ( d_wr_addr    ),
        .wr_wstrb   ( d_wr_wstrb   ),
        .wr_data    ( d_wr_data    ),
        .wr_rdy     ( d_wr_rdy     )
    );

    parameter ID_WIDTH = 4;
    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = 4;


    wire [ID_WIDTH-1:0]    axi_awid;
    /* verilator lint_off UNUSED */
    wire [31:0]            axi_awaddr;
    /* verilator lint_off UNUSED */
    wire [7:0]             axi_awlen;
    wire [2:0]             axi_awsize;
    wire [1:0]             axi_awburst;
    wire [1:0]             axi_awlock;
    wire [3:0]             axi_awcache;
    wire [2:0]             axi_awprot;
    wire                   axi_awvalid;
    wire                   axi_awready;
    /* verilator lint_off UNUSED */
    wire [ID_WIDTH-1:0]    axi_wid;
    /* verilator lint_on UNUSED */
    wire [DATA_WIDTH-1:0]  axi_wdata;
    wire [STRB_WIDTH-1:0]  axi_wstrb;
    wire                   axi_wlast;
    wire                   axi_wvalid;
    wire                   axi_wready;
    wire [ID_WIDTH-1:0]    axi_bid;
    wire [1:0]             axi_bresp;
    wire                   axi_bvalid;
    wire                   axi_bready;
    wire [ID_WIDTH-1:0]    axi_arid;
    /* verilator lint_off UNUSED */
    wire [31:0]            axi_araddr;
    /* verilator lint_on UNUSED */
    wire [7:0]             axi_arlen;
    wire [2:0]             axi_arsize;
    wire [1:0]             axi_arburst;
    wire [1:0]             axi_arlock;
    wire [3:0]             axi_arcache;
    wire [2:0]             axi_arprot;
    wire                   axi_arvalid;
    wire                   axi_arready;
    wire [ID_WIDTH-1:0]    axi_rid;
    wire [DATA_WIDTH-1:0]  axi_rdata;
    wire [1:0]             axi_rresp;
    wire                   axi_rlast;
    wire                   axi_rvalid;
    wire                   axi_rready;

    axi_bridge u_axi(
        .clk             ( clock       ),
        .reset           ( reset       ),

        .awid            ( axi_awid    ),
        .awaddr          ( axi_awaddr  ),
        .awlen           ( axi_awlen   ),
        .awsize          ( axi_awsize  ),
        .awburst         ( axi_awburst ),
        .awlock          ( axi_awlock  ),
        .awcache         ( axi_awcache ),
        .awprot          ( axi_awprot  ),
        .awvalid         ( axi_awvalid ),
        .awready         ( axi_awready ),
        .wid             ( axi_wid     ),
        .wdata           ( axi_wdata   ),
        .wstrb           ( axi_wstrb   ),
        .wlast           ( axi_wlast   ),
        .wvalid          ( axi_wvalid  ),
        .wready          ( axi_wready  ),
        .bid             ( axi_bid     ),
        .bresp           ( axi_bresp   ),
        .bvalid          ( axi_bvalid  ),
        .bready          ( axi_bready  ),
        .arid            ( axi_arid    ),
        .araddr          ( axi_araddr  ),
        .arlen           ( axi_arlen   ),
        .arsize          ( axi_arsize  ),
        .arburst         ( axi_arburst ),
        .arlock          ( axi_arlock  ),
        .arcache         ( axi_arcache ),
        .arprot          ( axi_arprot  ),
        .arvalid         ( axi_arvalid ),
        .arready         ( axi_arready ),
        .rid             ( axi_rid     ),
        .rdata           ( axi_rdata   ),
        .rresp           ( axi_rresp   ),
        .rlast           ( axi_rlast   ),
        .rvalid          ( axi_rvalid  ),
        .rready          ( axi_rready  ),

        .inst_rd_req     ( i_rd_req    ),
        .inst_rd_type    ( i_rd_type   ),
        .inst_rd_addr    ( i_rd_addr   ),
        .inst_rd_rdy     ( i_rd_rdy    ),
        .inst_ret_valid  ( i_ret_valid ),
        .inst_ret_last   ( i_ret_last  ),
        .inst_ret_data   ( i_ret_data  ),
        .inst_wr_req     ( 1'b0        ),
        .inst_wr_type    ( 3'b0        ),
        .inst_wr_addr    ( 32'b0       ),
        .inst_wr_wstrb   ( 4'b0        ),
        .inst_wr_data    ( 128'b0      ),
        /* verilator lint_off PINCONNECTEMPTY */
        .inst_wr_rdy     (             ),
        /* verilator lint_on PINCONNECTEMPTY */
                           
        .data_rd_req     ( d_rd_req    ),
        .data_rd_type    ( d_rd_type   ),
        .data_rd_addr    ( d_rd_addr   ),
        .data_rd_rdy     ( d_rd_rdy    ),
        .data_ret_valid  ( d_ret_valid ),
        .data_ret_last   ( d_ret_last  ),
        .data_ret_data   ( d_ret_data  ),
        .data_wr_req     ( d_wr_req    ),
        .data_wr_type    ( d_wr_type   ),
        .data_wr_addr    ( d_wr_addr   ),
        .data_wr_wstrb   ( d_wr_wstrb  ),
        .data_wr_data    ( d_wr_data   ),
        .data_wr_rdy     ( d_wr_rdy    ),

        /* verilator lint_off PINCONNECTEMPTY */
        .write_buffer_empty (          )
        /* verilator lint_on PINCONNECTEMPTY */
    );

    // https://github.com/alexforencich/verilog-axi
    // MIT License
    axi_ram #(
        .ADDR_WIDTH     ( 16            ),
        .DATA_WIDTH     ( 32            ),
        .ID_WIDTH       ( 4             )
    ) u_axi_ram(
        .clk            ( clock       ),
        .rst            ( reset       ),
        
        .s_axi_awid     ( axi_awid    ),
        .s_axi_awaddr   ( axi_awaddr[15:0] ),
        .s_axi_awlen    ( axi_awlen   ),
        .s_axi_awsize   ( axi_awsize  ),
        .s_axi_awburst  ( axi_awburst ),
        .s_axi_awlock   (|axi_awlock  ),
        .s_axi_awcache  ( axi_awcache ),
        .s_axi_awprot   ( axi_awprot  ),
        .s_axi_awvalid  ( axi_awvalid ),
        .s_axi_awready  ( axi_awready ),
        .s_axi_wdata    ( axi_wdata   ),
        .s_axi_wstrb    ( axi_wstrb   ),
        .s_axi_wlast    ( axi_wlast   ),
        .s_axi_wvalid   ( axi_wvalid  ),
        .s_axi_wready   ( axi_wready  ),
        .s_axi_bid      ( axi_bid     ),
        .s_axi_bresp    ( axi_bresp   ),
        .s_axi_bvalid   ( axi_bvalid  ),
        .s_axi_bready   ( axi_bready  ),
        .s_axi_arid     ( axi_arid    ),
        .s_axi_araddr   ( axi_araddr[15:0] ),
        .s_axi_arlen    ( axi_arlen   ),
        .s_axi_arsize   ( axi_arsize  ),
        .s_axi_arburst  ( axi_arburst ),
        .s_axi_arlock   (|axi_arlock  ),
        .s_axi_arcache  ( axi_arcache ),
        .s_axi_arprot   ( axi_arprot  ),
        .s_axi_arvalid  ( axi_arvalid ),
        .s_axi_arready  ( axi_arready ),
        .s_axi_rid      ( axi_rid     ),
        .s_axi_rdata    ( axi_rdata   ),
        .s_axi_rresp    ( axi_rresp   ),
        .s_axi_rlast    ( axi_rlast   ),
        .s_axi_rvalid   ( axi_rvalid  ),
        .s_axi_rready   ( axi_rready  )
    );
endmodule
