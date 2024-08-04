module axi_bridge_v2 (
    input               clock,
    input               reset,

    output  reg         arvalid,
    input               arready,
    output  reg [ 3:0]  arid,
    output  reg [31:0]  araddr,
    output  reg [ 7:0]  arlen,
    output  reg [ 2:0]  arsize,
    output      [ 1:0]  arburst,    // fixed
    output      [ 1:0]  arlock,     // fixed
    output      [ 3:0]  arcache,    // fixed
    output      [ 2:0]  arprot,     // fixed

    input               rvalid,
    output              rready,
    input       [ 3:0]  rid,
    input       [31:0]  rdata,
    /* verilator lint_off UNUSED */
    input       [ 1:0]  rresp,      // ignored
    /* verilator lint_on UNUSED */
    input               rlast,

    output  reg         awvalid,
    input               awready,
    output  reg [31:0]  awaddr,
    output  reg [ 7:0]  awlen,
    output  reg [ 2:0]  awsize,
    output      [ 3:0]  awid,       // fixed
    output      [ 1:0]  awburst,    // fixed
    output      [ 1:0]  awlock,     // fixed
    output      [ 3:0]  awcache,    // fixed
    output      [ 2:0]  awprot,     // fixed

    output  reg         wvalid,
    input               wready,
    output              wlast,
    output      [31:0]  wdata,
    output      [ 3:0]  wstrb,
    output      [ 3:0]  wid,        // fixed

    /* verilator lint_off UNUSED */
    input       [ 3:0]  bid,
    input       [ 1:0]  bresp,
    /* verilator lint_on UNUSED */
    input               bvalid,
    output  reg         bready,

    // icache
    input               i_rd_req     ,
    input       [ 2:0]  i_rd_type    ,
    input       [31:0]  i_rd_addr    ,
    output              i_rd_rdy     ,
    output              i_ret_valid  ,
    output              i_ret_last   ,
    output      [31:0]  i_ret_data   ,

    input               d_rd_req     ,
    output              d_wr_rdy     ,
    input       [ 2:0]  d_rd_type    ,
    input       [31:0]  d_rd_addr    ,
    output              d_rd_rdy     ,
    output              d_ret_valid  ,
    output              d_ret_last   ,
    output      [31:0]  d_ret_data   ,
    input               d_wr_req     ,
    input       [ 2:0]  d_wr_type    ,
    input       [31:0]  d_wr_addr    ,
    input       [ 3:0]  d_wr_wstrb   ,
    input      [127:0]  d_wr_data    ,
    output              write_buffer_empty
    );
    // Channel Sync
    wire            stall_rd;
    assign stall_rd = !(wr_s_is_idle);

    // RD Channel
    /// axi fixed signals
    assign arburst  = 2'b01;
    assign arlock   = 2'b00;
    assign arcache  = 4'b0000;
    assign arprot   = 3'b000;

    /// req
    wire            rd_i_req_is_line = i_rd_type == 3'b100;
    wire    [ 7:0]  rd_i_req_len = rd_i_req_is_line ? 8'b11 : 8'b0;
    wire    [ 2:0]  rd_i_req_size = rd_i_req_is_line ? 3'b010 : i_rd_type;
    wire            rd_d_req_is_line = d_rd_type == 3'b100;
    wire    [ 7:0]  rd_d_req_len = rd_d_req_is_line ? 8'b11 : 8'b0;
    wire    [ 2:0]  rd_d_req_size = rd_d_req_is_line ? 3'b010 : d_rd_type;
    wire    [ 7:0]  rd_req_len;
    wire    [ 2:0]  rd_req_size;
    assign rd_req_len = (d_rd_req) ? rd_d_req_len : rd_i_req_len;
    assign rd_req_size = (d_rd_req) ? rd_d_req_size : rd_i_req_size;

    /// state machine
    localparam  rd_s_idle   = 0;
    localparam  rd_s_send   = 1;
    reg     [ 1:0]  rd_s;
    wire    rd_s_is_idle = rd_s == rd_s_idle;
    wire    rd_s_is_send = rd_s == rd_s_send;
    //// idle
    wire    rd_send_fin = rd_s_is_send && arready;
    wire    rd_req_recv = !stall_rd && (d_rd_req || i_rd_req) && (rd_s_is_idle || (rd_s_is_send && rd_send_fin));

    always @(posedge clock) begin
        if (reset) begin
            rd_s <= rd_s_idle;
            arvalid <= 0;
            arid <= 0;
            araddr <= 0;
            arlen <= 0;
            arsize <= 0;
        end else case (rd_s)
            rd_s_idle: begin
                if (rd_req_recv) begin
                    rd_s <= rd_s_send;
                    arvalid <= 1;
                    arlen <= rd_req_len;
                    arsize <= rd_req_size;
                    if (d_rd_req) begin
                        arid <= 4'd1;
                        araddr <= d_rd_addr;                                                
                    end else begin
                        arid <= 4'd0;
                        araddr <= i_rd_addr;                        
                    end
                end
            end 
            rd_s_send: begin
                if (arready) begin
                    if (rd_req_recv) begin
                        rd_s <= rd_s_send;
                        arvalid <= 1;
                        arlen <= rd_req_len;
                        arsize <= rd_req_size;
                        if (d_rd_req) begin
                            arid <= 4'd1;
                            araddr <= d_rd_addr;                                                
                        end else begin
                            arid <= 4'd0;
                            araddr <= i_rd_addr;                        
                        end
                    end else begin
                        arvalid <= 0;
                        rd_s <= rd_s_idle;
                    end                   
                end
            end
            default: begin
                rd_s <= rd_s_idle;
            end
        endcase
    end

    /// i/o
    assign i_rd_rdy = rd_req_recv && !d_rd_req;
    assign d_rd_rdy = rd_req_recv;

    // RET Channel
    wire    ret_is_data = rid == 4'd1;
    /// axi fixed signals
    assign rready = 1;
    /// i/o
    assign i_ret_valid = rvalid && !ret_is_data;
    assign i_ret_last = rlast;
    assign i_ret_data = rdata;
    assign d_ret_valid = rvalid && ret_is_data;
    assign d_ret_last = rlast;
    assign d_ret_data = rdata;

    // WR Channel
    /// axi fixed signals
    assign awid     = 4'd1;
    assign awburst  = 2'b01;
    assign awlock   = 2'b00;
    assign awcache  = 4'b0000;
    assign awprot   = 3'b000;

    assign wid      = 4'd1;

    /// state machine
    localparam  wr_s_idle   = 0;
    localparam  wr_s_reqw   = 1;
    localparam  wr_s_send   = 2;
    localparam  wr_s_recv   = 3;
    localparam  wr_s_reset  = 4;
    
    reg     [ 2:0]  wr_s;
    wire wr_s_is_idle = wr_s == wr_s_idle;
    wire wr_s_is_send = wr_s == wr_s_send;
    // wire wr_s_is_recv = wr_s == wr_s_recv;
    // s_idle
    wire    [ 7:0]  wr_req_len;
    wire    [ 2:0]  wr_req_size;
    reg     [ 7:0]  wr_req_buf_len;
    reg     [ 3:0]  wr_req_buf_wstrb;
    /* TODO: len change */
    reg     [31:0]  wr_req_buf_data     [ 0:3];
    wire    wr_req_is_line = d_wr_type == 3'b100;
    assign wr_req_len = wr_req_is_line ? 8'b11 : 8'b0;
    assign wr_req_size = wr_req_is_line ? 3'b010 : d_wr_type;
    // s_send
    reg     [ 7:0]  wr_send_cnt;
    wire send_fin = wready && (wr_send_cnt == wr_req_buf_len);
    always @(posedge clock) begin
        if (reset) begin
            wr_s <= wr_s_idle;
            awvalid <= 0;
            awaddr <= 0;
            awlen <= 0;
            awsize <= 0;
            wvalid <= 0;
            bready <= 0;
        end else case (wr_s)
            wr_s_idle: begin
                if (d_wr_req) begin
                    wr_s <= wr_s_reqw;
                    awvalid <= 1;
                    awaddr <= d_wr_addr;
                    awlen <= wr_req_len;
                    awsize <= wr_req_size;
                        {wr_req_buf_wstrb, wr_req_buf_len}
                    <=  {d_wr_wstrb   , wr_req_len    };                    
                        {wr_req_buf_data[3], wr_req_buf_data[2], wr_req_buf_data[1], wr_req_buf_data[0]}
                    <=  {d_wr_data};
                end
            end
            wr_s_reqw: begin
                if (awready) begin
                    wr_s <= wr_s_send;
                    awvalid <= 0;
                    wvalid <= 1;
                    wr_send_cnt <= 0;
                end
            end
            wr_s_send: begin
                if (wready) begin
                    if (send_fin) begin
                        wr_s <= wr_s_recv;
                        wvalid <= 0;
                        bready <= 1;
                    end else begin
                        wr_send_cnt <= wr_send_cnt + 1;
                    end
                end
            end
            wr_s_recv: begin
                if (bvalid && bready) begin
                    wr_s <= wr_s_idle;
                    bready <= 0;
                end
            end
            wr_s_reset: begin
                wr_s <= wr_s_idle;
                wr_send_cnt <= 0;
                wvalid <= 0;
                bready <= 0;
            end
            default: begin
                wr_s <= wr_s_reset;
            end
        endcase
    end
    /// i/o
    assign wstrb = wr_req_buf_wstrb;
    /* TODO: len change */
    assign wdata = wr_req_buf_data[wr_send_cnt[1:0]];
    assign wlast = (wr_s_is_send && wr_send_cnt == wr_req_buf_len);

    assign d_wr_rdy = wr_s_is_idle;
    assign write_buffer_empty = 1;
endmodule
