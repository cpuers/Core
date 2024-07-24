/* verilator lint_off DECLFILENAME */

/* verilator lint_off UNUSED */
module icache_dummy(
    input  wire          clock,
    input  wire          reset,

    // common control (c) channel
    input  wire          valid,      // in cpu, valid no dep on ready;
    output wire          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    input  wire  [31:0]  araddr,
    input  wire          uncached,
    //// read data (r) channel
    output wire          rvalid,
    output wire [127:0]  rdata,
    output wire          rhit,
    /// cpu cacop
    input  wire          cacop_valid,
    output wire          cacop_ready,
    input  wire  [ 1:0]  cacop_code, // code[4:3]
    input  wire  [31:0]  cacop_addr,
    
    // axi bridge
    output wire          rd_req,
    output wire  [ 2:0]  rd_type,
    output wire  [31:0]  rd_addr,
    input  wire          rd_rdy,
    input  wire          ret_valid,
    input  wire          ret_last,
    input  wire  [31:0]  ret_data
    );

    localparam      state_idle = 0;     
    localparam      state_request = 1;  // wait axi rd_ready
    localparam      state_receive = 2;  // wait axi ret_last
    localparam      state_reset = 3;
    reg     [ 2:0]  state;
    wire state_is_idle = (state == state_idle);
    wire state_is_request = (state == state_request);
    wire state_is_receive = (state == state_receive);
    
    reg     [31:0]  request_buffer;

    reg     [31:0]  buffer  [ 0:2];
    reg     [ 1:0]  buffer_cnt;

    wire            buffer_receive_end;
    assign buffer_receive_end = 
        (state == state_receive) && (ret_valid && ret_last | (buffer_cnt == 2'd3));

    assign ready = state_is_idle;
    assign rvalid = buffer_receive_end;
    assign rdata = 
        {128{rvalid}} & {ret_data, buffer[2], buffer[1], buffer[0]};
    assign rhit = 1'b0;

    assign cacop_ready = 1'b1;

    assign rd_req = state_is_request;
    assign rd_type = 3'b100;
    assign rd_addr = {{28{state_is_request}}, 4'b0} & request_buffer;

    /* State Machine */
    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    state <= state_request;
                    request_buffer <= araddr;
                end
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    buffer_cnt <= 0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (buffer_receive_end) begin
                        state <= state_idle;
                    end else begin
                        buffer[buffer_cnt] <= ret_data;
                        buffer_cnt <= buffer_cnt + 1;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule

module icache_dummy_v2 (
    input  wire          clock,
    input  wire          reset,

    // common control (c) channel
    input  wire          valid,      // in cpu, valid no dep on ready;
    output wire          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    input  wire  [31:0]  araddr,
    input  wire          uncached,
    //// read data (r) channel
    output wire          rvalid,
    output wire [127:0]  rdata,
    output wire          rhit,
    /// cpu cacop
    input  wire          cacop_valid,
    output wire          cacop_ready,
    input  wire  [ 1:0]  cacop_code, // code[4:3]
    input  wire  [31:0]  cacop_addr,
    
    // axi bridge
    output wire          rd_req,
    output wire  [ 2:0]  rd_type,
    output wire  [31:0]  rd_addr,
    input  wire          rd_rdy,
    input  wire          ret_valid,
    input  wire          ret_last,
    input  wire  [31:0]  ret_data
    );

    localparam  state_idle = 0;
    localparam  state_receive = 1;
    localparam  state_reset = 2;
    reg     [ 2:0]  state;
    wire state_is_idle = (state == state_idle);
    wire state_is_receive = (state == state_receive);

    reg     [31:0]  receive_buffer  [ 0:2];
    reg     [ 1:0]  receive_buffer_cnt;

    wire            receive_finish;
    assign receive_finish = 
        state_is_receive && ret_valid && (ret_last || receive_buffer_cnt == 2'd3);

    //  (state_is_idle && rd_rdy) ||
    //  (state_is_receive && receive_finish && rd_rdy);
    assign ready = (state_is_idle || (state_is_receive && receive_finish)) && rd_rdy;

    assign rvalid = receive_finish;
    assign rdata = {ret_data, receive_buffer[2], receive_buffer[1], receive_buffer[0]};
    assign rhit = 1'b0;

    assign cacop_ready = 1'b1;

    //  (state_is_idle && valid) ||
    //  (state_is_receive && receive_finish && valid);
    assign rd_req = (state_is_idle || (state_is_receive && receive_finish)) && valid;
    assign rd_type = 3'b100;
    assign rd_addr = {{28{1'b1}}, 4'b0} & araddr;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    if (rd_rdy) begin
                        state <= state_receive;
                        receive_buffer_cnt <= 0;
                    end
                end
            end 
            state_receive: begin
                if (ret_valid) begin
                    if (receive_finish) begin
                        if (valid) begin
                            if (rd_rdy) begin
                                state <= state_receive;
                                receive_buffer_cnt <= 0;
                            end else begin
                                state <= state_idle;
                            end
                        end else begin
                            state <= state_idle;
                        end
                    end else begin
                        receive_buffer[receive_buffer_cnt] <= ret_data;
                        receive_buffer_cnt <= receive_buffer_cnt + 1;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule
/* verilator lint_on UNUSED */


//module icache_v1 (
//    input           clock,
//    input           reset,
//    // cpu
//    input           valid,
//    output          addr_ok,
//    input   [31:0]  addr,
//    output          data_ok,
//    output  [127:0] rdata,
//    // axi_bridge
//    output          rd_req,
//    output  [ 2:0]  rd_type,
//    output  [31:0]  rd_addr,
//    input           rd_rdy,
//    input           ret_valid,
//    input   [31:0]  ret_data
//);
//    wire    [19:0]  tag;
//    wire    [ 7:0]  idx;

//    assign tag = addr[31:12];
//    assign idx = addr[11:4];

//    genvar  i;

//    // ************
//    // * Datapath *
//    // ************

//    wire            tagv_ena;
//    wire            tagv_wea;
//    wire    [ 7:0]  tagv_addra;
//    wire    [20:0]  tagv_dina;
//    wire    [20:0]  tagv_douta;

//    wire            data_ena;
//    wire            data_wea;
//    wire    [ 7:0]  data_addra;
//    wire    [127:0] data_dina;
//    wire    [127:0] data_douta;

//    assign tagv_ena = (state_is_idle && valid);
//    assign tagv_wea = (state_is_wb);
//    assign tagv_addra = 
//        (state_is_wb) ? request_buffer_idx : idx;
//    assign tagv_dina = {request_buffer_tag, 1'b1};

//    assign data_ena = state_is_lookup1 && hit;
//    assign data_wea = (state_is_wb);
//    assign data_addra = request_buffer_idx;
//    assign data_dina = refill_res;

//    // cpu

//    assign addr_ok = state_is_idle;
//    assign data_ok = state_is_lookup2 | state_is_wb;
//    assign rdata =
//        ({128{state_is_lookup2}} & data_douta) |
//        ({128{state_is_wb}} & refill_res);

//    // axi

//    assign rd_req =
//        (state == state_request && rd_rdy);
//    assign rd_addr =
//        {request_buffer_tag, request_buffer_idx, 4'b0};

//    /* cache */
//    `ifdef TEST
//    sram_sim #(
//        .ADDR_WIDTH     (8          ),
//        .DATA_WIDTH     (21         )
//        // [20:1] tag   [0:0] v
//    ) u_tagv_sram (
//        .clka           (clock      ),
//        .ena            (tagv_ena   ),
//        .wea            (tagv_wea   ),
//        .addra          (tagv_addra ),
//        .dina           (tagv_dina  ),
//        .douta          (tagv_douta )
//    );

//    sram_sim #(
//        .ADDR_WIDTH     (8          ),
//        .DATA_WIDTH     (128        )
//    ) u_data_sram (
//        .clka           (clock      ),
//        .ena            (data_ena   ),
//        .wea            (data_wea   ),
//        .addra          (data_addra ),
//        .dina           (data_dina  ),
//        .douta          (data_douta )
//    );

//    `else

//    `endif

//    /* request buffer */
//    reg     [19:0]  request_buffer_tag;
//    reg     [ 7:0]  request_buffer_idx;

//    /* hit */
//    wire            hit;
//    assign hit = tagv_douta[0] & (request_buffer_tag == tagv_douta[20:1]);

//    /* refill buffer */
//    reg     [31:0]  refill_buffer   [0:3];
//    reg     [ 1:0]  refill_count;
//    wire            refill_done;
//    assign refill_done = refill_count == 2'd3;
//    wire    [127:0] refill_res;
//    assign refill_res =
//        {refill_buffer[0], refill_buffer[1], refill_buffer[2], refill_buffer[3]};



//    // *****************
//    // * State Machine *
//    // *****************

//    localparam state_idle    = 4'd0;
//    localparam state_lookup1 = 4'd1;
//    localparam state_lookup2 = 4'd2;
//    localparam state_request = 4'd3;
//    localparam state_receive = 4'd4;
//    localparam state_wb      = 4'd5;

//    reg     [ 3:0]  state;
//    wire            state_is_idle;
//    wire            state_is_lookup1;
//    wire            state_is_lookup2;
//    wire            state_is_request;
//    wire            state_is_receive;
//    wire            state_is_wb;
//    assign state_is_idle = state == state_idle;
//    assign state_is_lookup1 = state == state_lookup1;
//    assign state_is_lookup2 = state == state_lookup2;
//    assign state_is_request = state == state_request;
//    assign state_is_receive = state == state_receive;
//    assign state_is_wb = state == state_wb;

//    always @(posedge clock) begin
//        if (reset) begin
//            state <= state_idle;

//            request_buffer_idx <= 8'd0;
//            request_buffer_tag <= 20'd0;
//            refill_buffer[0] <= 32'd0;
//            refill_buffer[1] <= 32'd0;
//            refill_buffer[2] <= 32'd0;
//            refill_buffer[3] <= 32'd0;
//            refill_count <= 2'd0;
//        end else case (state)
//            state_idle: begin
//                if (valid) begin
//                    state <= state_lookup1;

//                    request_buffer_idx <= idx;
//                    request_buffer_tag <= tag;
//                end                
//            end 
//            state_lookup1: begin
//                if (hit) begin
//                    state <= state_lookup2;                    
//                end else begin
//                    state <= state_request;
//                end
//            end
//            state_lookup2: begin
//                state <= state_idle;                
//            end
//            state_request: begin
//                if (rd_rdy) begin
//                    state <= state_receive;
//                    refill_count <= 2'd0;
//                end
//            end
//            state_receive: begin
//                if (ret_valid) begin
//                    refill_buffer[refill_count] <= ret_data;
//                    if (refill_done) begin
//                        state <= state_idle;
//                    end else begin
//                        refill_count <= refill_count + 1;
//                    end
//                end
//            end
//            state_wb: begin
//                state <= state_idle;                
//            end
//            default: begin
//                state <= state_idle;
//            end
//        endcase
//    end
//endmodule

module icache_v2(
    input           clock,
    input           reset,

    // common control (c) channel
    input           valid,      // in cpu, valid no dep on ready;
    output          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    /* verilator lint_off UNUSED */
    input   [31:0]  araddr,
    /* verilator lint_on UNUSED */
    input           uncached,
    //// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    output          rhit,
    /// cpu cacop
    input           cacop_en,
    input   [ 1:0]  cacop_code, // code[4:3]
    /* verilator lint_off UNUSED */
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */
    
    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data
    );

    // cache ports

    wire            tagv_ena;
    wire            tagv_wea;
    wire    [ 7:0]  tagv_addra;
    wire    [20:0]  tagv_dina;
    wire    [20:0]  tagv_douta;

    wire            data_ena;
    wire            data_wea;
    wire    [ 7:0]  data_addra;
    wire   [127:0]  data_dina;
    wire   [127:0]  data_douta;

    // request buffer

    reg     [19:0]  request_buffer_tag;
    reg     [ 7:0]  request_buffer_idx;
    reg             request_buffer_uncached;

    // state machine

    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_request = 2;
    localparam      state_receive = 3;
    localparam      state_cacop = 4;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    wire state_is_request = state == state_request;
    wire state_is_receive = state == state_receive;
    wire state_is_cacop = state == state_cacop;
    /// idle
    wire idle_cacop_is_init = cacop_code == 2'd0;
    wire idle_cacop_is_index = cacop_code == 2'd1;
    wire idle_cacop_is_lookup = cacop_code == 2'd2;
    /// lookup
    wire            lookup_hit;
    wire            lookup_v;
    wire    [19:0]  lookup_tag;
    assign lookup_v = tagv_douta[20];
    assign lookup_tag = tagv_douta[19:0];
    assign lookup_hit = lookup_v && (lookup_tag == request_buffer_tag);
    assign rhit = state_is_lookup && lookup_hit;
    /// receive
    reg     [31:0]  receive_buffer      [ 0:2];
    reg     [ 1:0]  receive_buffer_cnt;
    wire            receive_finish;
    wire   [127:0]  receive_result;
    assign receive_finish = ret_valid && (ret_last | (receive_buffer_cnt == 2'd3));
    assign receive_result = {ret_data, receive_buffer[2], receive_buffer[1], receive_buffer[0]};
    /// cacop

    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            request_buffer_tag <= 0;
            request_buffer_idx <= 0;
            request_buffer_uncached <= 0;
        end else case (state)
            state_idle: begin
                if (cacop_en) begin
                    if (idle_cacop_is_lookup) begin
                        state <= state_cacop;
                        request_buffer_tag <= cacop_addr[31:12];
                        request_buffer_idx <= cacop_addr[11:4];
                    end else begin
                        state <= state_idle;
                    end
                end else if (valid) begin
                    if (uncached) begin
                        state <= state_request;
                    end else begin
                        state <= state_lookup;
                    end
                    request_buffer_tag <= araddr[31:12];
                    request_buffer_idx <= araddr[11:4];
                    request_buffer_uncached <= uncached;
                end
            end
            state_lookup: begin
                if (lookup_hit) begin
                    state <= state_idle;                    
                end else begin
                    state <= state_request;                    
                end
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    receive_buffer_cnt <= 0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (receive_finish) begin
                        state <= state_idle;
                    end else begin
                        receive_buffer[receive_buffer_cnt] <= ret_data;
                        receive_buffer_cnt <= receive_buffer_cnt + 1;                        
                    end
                end
            end
            state_cacop: begin
                state <= state_idle;                
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end

    // i/o

    assign ready = state_is_idle;
    wire   lookup_ret = state_is_lookup && lookup_hit;
    wire   receive_ret = state_is_receive && receive_finish;
    assign rvalid = lookup_ret || receive_ret;
    assign rdata = 
        ({128{lookup_ret}} & data_douta) |
        ({128{receive_ret}} & receive_result);
    assign rd_req = state_is_request;
    assign rd_type = 3'b100;
    assign rd_addr = {request_buffer_tag, request_buffer_idx, 4'd0};

    // cache sram

    `ifdef TEST
    sram_sim #(
        .ADDR_WIDTH (8      ),
        // tag: [19:0], v: [20]
        .DATA_WIDTH (21     )
    ) u_tagv_sram(
        .clka   (clock      ),
        .ena    (tagv_ena   ),
        .wea    (tagv_wea   ),
        .addra  (tagv_addra ),
        .dina   (tagv_dina  ),
        .douta  (tagv_douta )
    );

    sram_sim #(
        .ADDR_WIDTH (8      ),
        .DATA_WIDTH (128    )
    ) u_data_sram(
        .clka   (clock      ),
        .ena    (data_ena   ),
        .wea    (data_wea   ),
        .addra  (data_addra ),
        .dina   (data_dina  ),
        .douta  (data_douta )
    );
    `else

    `endif

    // cache control

    wire    [ 7:0]  cache_idx =
        ({8{state_is_idle & !cacop_en}}         & araddr[11:4]) |
        ({8{state_is_idle &  cacop_en}}         & cacop_addr[11:4]) |
        ({8{state_is_receive | state_is_cacop}} & request_buffer_idx);

    assign tagv_ena = 
        (state_is_idle && (valid || cacop_en)) || 
        (state_is_receive && receive_finish);
    assign tagv_wea = 
        (state_is_idle && cacop_en && (
            idle_cacop_is_init || 
            idle_cacop_is_index
        )) ||
        (state_is_receive && receive_finish && !request_buffer_uncached) ||
        (state_is_cacop && lookup_hit);         // Reuse state_lookup datapath
    assign tagv_addra = cache_idx;
    assign tagv_dina = 
        (state_is_receive) ? {1'b1, request_buffer_tag} : 21'b0; 

    assign data_ena = 
        (state_is_idle && valid) || 
        (state_is_receive && receive_finish && !request_buffer_uncached);
    assign data_wea = state_is_receive && receive_finish;
    assign data_addra = cache_idx;
    assign data_dina = receive_result;
endmodule


module icache_v3(
    input           clock,
    input           reset,

    // common control (c) channel
    input           valid,      // in cpu, valid no dep on ready;
    output          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    /* verilator lint_off UNUSED */
    input   [31:0]  araddr,
    /* verilator lint_on UNUSED */
    input           uncached,
    //// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    output          rhit,
    /// cpu cacop
    input           cacop_en,
    input   [ 1:0]  cacop_code, // code[4:3]
    /* verilator lint_off UNUSED */
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */
    
    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data
    );

    localparam  ICACHE_WAY = 2;
    genvar i;   // way

    // cache ports

    wire            tagv_ena    [0:ICACHE_WAY-1];
    wire            tagv_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:ICACHE_WAY-1];

    wire            data_ena    [0:ICACHE_WAY-1];
    wire            data_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  data_addra  [0:ICACHE_WAY-1];
    wire   [127:0]  data_dina   [0:ICACHE_WAY-1];
    wire   [127:0]  data_douta  [0:ICACHE_WAY-1];

    // request buffer

    reg     [19:0]  request_buffer_tag;
    reg     [ 7:0]  request_buffer_idx;
    reg             request_buffer_uncached;
    reg [$clog2(ICACHE_WAY)-1:0] request_buffer_cacop_way;

    // state machine

    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_request = 2;
    localparam      state_receive = 3;
    localparam      state_cacop = 4;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    wire state_is_request = state == state_request;
    wire state_is_receive = state == state_receive;
    wire state_is_cacop = state == state_cacop;
    /// idle
    wire idle_cacop_is_init = cacop_code == 2'd0;
    wire idle_cacop_is_index = cacop_code == 2'd1;
    wire idle_cacop_is_lookup = cacop_code == 2'd2;
    /// lookup
    wire    [ICACHE_WAY-1:0]    lookup_way_v;
    wire    [19:0]              lookup_way_tag  [0:ICACHE_WAY-1];
    wire    [ICACHE_WAY-1:0]    lookup_way_hit;
    reg     [ICACHE_WAY-1:0]    lookup_way_v_result;
    wire                        lookup_hit;
    reg    [127:0]              lookup_hit_data;    // combinational logic
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign lookup_way_v[i] = tagv_douta[i][0];
            assign lookup_way_tag[i] = tagv_douta[i][20:1];
            assign lookup_way_hit[i] =
                lookup_way_v[i] && (lookup_way_tag[i] == request_buffer_tag);
        end
    endgenerate
    assign lookup_hit = |lookup_way_hit;
    integer j;
    always @(*) begin
        lookup_hit_data = 128'b0;        
        for (j = 0; j < ICACHE_WAY; j = j + 1) begin
            lookup_hit_data = lookup_hit_data | 
                ({128{lookup_way_hit[j]}} & data_douta[j]);
        end
    end


    /// receive
    reg     [31:0]  receive_buffer      [ 0:2];
    reg     [ 1:0]  receive_buffer_cnt;
    wire            receive_finish;
    wire   [127:0]  receive_result;
    assign receive_finish = ret_valid && (ret_last | (receive_buffer_cnt == 2'd3));
    assign receive_result = {ret_data, receive_buffer[2], receive_buffer[1], receive_buffer[0]};
    /// cacop

    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            request_buffer_tag <= 0;
            request_buffer_idx <= 0;
            request_buffer_uncached <= 0;
            request_buffer_cacop_way <= 0;
        end else case (state)
            state_idle: begin
                if (cacop_en) begin
                    if (idle_cacop_is_lookup) begin
                        state <= state_cacop;
                        request_buffer_tag <= cacop_addr[31:12];
                        request_buffer_idx <= cacop_addr[11:4];
                        request_buffer_cacop_way <= cacop_addr[$clog2(ICACHE_WAY)-1:0];
                    end else begin
                        state <= state_idle;
                    end
                end else if (valid) begin
                    if (uncached) begin
                        state <= state_request;
                    end else begin
                        state <= state_lookup;
                    end
                    request_buffer_idx <= araddr[11:4];
                    request_buffer_tag <= araddr[31:12];
                    request_buffer_uncached <= uncached;
                end
            end
            state_lookup: begin
                if (lookup_hit) begin
                    state <= state_idle;
                end else begin
                    state <= state_request;
                    lookup_way_v_result <= lookup_way_v;
                end
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    receive_buffer_cnt <= 0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (receive_finish) begin
                        state <= state_idle;
                    end else begin
                        receive_buffer[receive_buffer_cnt] <= ret_data;
                        receive_buffer_cnt <= receive_buffer_cnt + 1;
                    end
                end
            end
            state_cacop: begin
                state <= state_idle;
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end

    // i/o
    assign ready = state_is_idle;
    wire   lookup_ret = state_is_lookup && lookup_hit;
    wire   receive_ret = state_is_receive && receive_finish;
    assign rvalid = lookup_ret || receive_ret;
    assign rdata = 
        ({128{lookup_ret}} & lookup_hit_data) |
        ({128{receive_ret}} & receive_result);
    assign rhit = state_is_lookup && lookup_hit;
    assign rd_req = state_is_request;
    assign rd_type = 3'b100;
    assign rd_addr = {request_buffer_tag, request_buffer_idx, 4'd0};

    // cache sram

    `ifdef TEST
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                // [20:1] tag   [0:0] v
                .DATA_WIDTH     ( 21            )
            ) u_tagv_sram(
                .clka           (clock          ),
                .ena            (tagv_ena   [i] ),
                .wea            (tagv_wea   [i] ),
                .addra          (tagv_addra [i] ),
                .dina           (tagv_dina  [i] ),
                .douta          (tagv_douta [i] )
            );

            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 128           )
            ) u_data_sram(
                .clka           (clock          ),
                .ena            (data_ena   [i] ),
                .wea            (data_wea   [i] ),
                .addra          (data_addra [i] ),
                .dina           (data_dina  [i] ),
                .douta          (data_douta [i] )
            );
        end
    endgenerate
    `else

    `endif

    // cache control

    wire    [ 7:0]                      cache_idx =
        ({8{state_is_idle & !cacop_en}}         & araddr[11:4]) |
        ({8{state_is_idle &  cacop_en}}         & cacop_addr[11:4]) |
        ({8{state_is_receive | state_is_cacop}} & request_buffer_idx);
    wire    [$clog2(ICACHE_WAY)-1:0]    cache_way = 
        ({$clog2(ICACHE_WAY){state_is_idle}}    & cacop_addr[$clog2(ICACHE_WAY)-1:0]) |
        ({$clog2(ICACHE_WAY){state_is_cacop}}   & request_buffer_cacop_way);
    wire    [ICACHE_WAY-1:0]            replace_way_en;
    // assume ICACHE_WAY == 2
    replace_rand_2 u_replace(
        .clock      (clock),
        .reset      (reset),
        .en         (state_is_receive && receive_finish),
        .valid_way  (lookup_way_v_result),
        .replace_en (replace_way_en)
    );

    wire    tagv_ena_i = 
        (state_is_idle && valid) || 
        (state_is_receive && receive_finish) ||
        (state_is_cacop);
    wire    [20:0] tagv_dina_i = 
        (state_is_receive) ? {request_buffer_tag, 1'b1} : 21'b0; 
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = tagv_ena_i;
            assign tagv_wea[i] = 
                (state_is_idle && cacop_en && (cache_way == i) &&(
                    idle_cacop_is_init || 
                    idle_cacop_is_index
                )) ||
                (state_is_receive && receive_finish && replace_way_en[i]) ||
                (state_is_cacop && lookup_way_hit[i]);
            assign tagv_addra[i] = cache_idx;
            assign tagv_dina[i] = tagv_dina_i;
        end
    endgenerate

    wire data_ena_i =
        (state_is_idle && valid && !cacop_en) || 
        (state_is_receive && receive_finish && !request_buffer_uncached) ||
        (state_is_cacop);
    wire data_wea_i = state_is_receive && receive_finish && !request_buffer_uncached;
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign data_ena[i] = data_ena_i;
            assign data_wea[i] = data_wea_i && replace_way_en[i];
            assign data_addra[i] = cache_idx;
            assign data_dina[i] = receive_result;
        end
    endgenerate
endmodule


module icache_v4(
    input           clock,
    input           reset,

    // common control (c) channel
    input           valid,      // in cpu, valid no dep on ready;
    output          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    /* verilator lint_off UNUSED */
    input   [31:0]  araddr,
    /* verilator lint_on UNUSED */
    input           uncached,
    //// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    output          rhit,
    /// cpu cacop
    input           cacop_en,
    input   [ 1:0]  cacop_code, // code[4:3]
    /* verilator lint_off UNUSED */
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */
    
    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data
    );

    localparam  ICACHE_WAY = 2;
    genvar i;   // way

    // cache ports

    wire            tagv_ena    [0:ICACHE_WAY-1];
    wire            tagv_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:ICACHE_WAY-1];

    wire            data_ena    [0:ICACHE_WAY-1];
    wire            data_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  data_addra  [0:ICACHE_WAY-1];
    wire   [127:0]  data_dina   [0:ICACHE_WAY-1];
    wire   [127:0]  data_douta  [0:ICACHE_WAY-1];

    reg             lru         [0:255];

    // request buffer

    reg     [19:0]  request_buffer_tag;
    reg     [ 7:0]  request_buffer_idx;
    reg             request_buffer_uncached;
    reg [$clog2(ICACHE_WAY)-1:0] request_buffer_cacop_way;

    // state machine

    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_request = 2;
    localparam      state_receive = 3;
    localparam      state_cacop = 4;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    wire state_is_request = state == state_request;
    wire state_is_receive = state == state_receive;
    wire state_is_cacop = state == state_cacop;
    /// idle
    wire idle_cacop_is_init = cacop_code == 2'd0;
    wire idle_cacop_is_index = cacop_code == 2'd1;
    wire idle_cacop_is_lookup = cacop_code == 2'd2;
    /// lookup
    wire    [ICACHE_WAY-1:0]    lookup_way_v;
    wire    [19:0]              lookup_way_tag  [0:ICACHE_WAY-1];
    wire    [ICACHE_WAY-1:0]    lookup_way_hit;
    reg     [ICACHE_WAY-1:0]    lookup_way_v_result;
    wire                        lookup_hit;
    reg    [127:0]              lookup_hit_data;    // combinational logic
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign lookup_way_v[i] = tagv_douta[i][0];
            assign lookup_way_tag[i] = tagv_douta[i][20:1];
            assign lookup_way_hit[i] =
                lookup_way_v[i] && (lookup_way_tag[i] == request_buffer_tag);
        end
    endgenerate
    assign lookup_hit = |lookup_way_hit;
    integer j;
    always @(*) begin
        lookup_hit_data = 128'b0;        
        for (j = 0; j < ICACHE_WAY; j = j + 1) begin
            lookup_hit_data = lookup_hit_data | 
                ({128{lookup_way_hit[j]}} & data_douta[j]);
        end
    end


    /// receive
    reg     [31:0]  receive_buffer      [ 0:2];
    reg     [ 1:0]  receive_buffer_cnt;
    wire            receive_finish;
    wire   [127:0]  receive_result;
    assign receive_finish = ret_last | (receive_buffer_cnt == 2'd3);
    assign receive_result = {ret_data, receive_buffer[2], receive_buffer[1], receive_buffer[0]};
    /// cacop

    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            request_buffer_tag <= 0;
            request_buffer_idx <= 0;
            request_buffer_uncached <= 0;
            request_buffer_cacop_way <= 0;
        end else case (state)
            state_idle: begin
                if (cacop_en) begin
                    if (idle_cacop_is_lookup) begin
                        state <= state_cacop;
                        request_buffer_tag <= cacop_addr[31:12];
                        request_buffer_idx <= cacop_addr[11:4];
                        request_buffer_cacop_way <= cacop_addr[$clog2(ICACHE_WAY)-1:0];
                    end else begin
                        state <= state_idle;
                    end
                end
                if (valid) begin
                    if (uncached) begin
                        state <= state_request;
                    end else begin
                        state <= state_lookup;
                    end
                    request_buffer_idx <= araddr[11:4];
                    request_buffer_tag <= araddr[31:12];
                    request_buffer_uncached <= uncached;
                end
            end
            state_lookup: begin
                if (lookup_hit) begin
                    state <= state_idle;
                    lru[request_buffer_idx] <= (lookup_way_hit == 2'b01) ? 0 : 1;
                end else begin
                    state <= state_request;
                    lookup_way_v_result <= lookup_way_v;
                end
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    receive_buffer_cnt <= 0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (receive_finish) begin
                        state <= state_idle;
                    end else begin
                        receive_buffer[receive_buffer_cnt] <= ret_data;
                        receive_buffer_cnt <= receive_buffer_cnt + 1;
                        lru[request_buffer_idx] <= (replace_way_en == 2'b01) ? 0 : 1;
                    end
                end
            end
            state_cacop: begin
                state <= state_idle;
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end

    // i/o
    assign ready = state_is_idle;
    wire   lookup_ret = state_is_lookup && lookup_hit;
    wire   receive_ret = state_is_receive && receive_finish;
    assign rvalid = lookup_ret || receive_ret;
    assign rdata = 
        ({128{lookup_ret}} & lookup_hit_data) |
        ({128{receive_ret}} & receive_result);
    assign rd_req = (state_is_lookup && !lookup_hit) || state_is_request;
    assign rd_type = 3'b100;
    assign rd_addr = {request_buffer_tag, 12'd0};

    // cache sram

    `ifdef TEST
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                // [20:1] tag   [0:0] v
                .DATA_WIDTH     ( 21            )
            ) u_tagv_sram(
                .clka           (clock          ),
                .ena            (tagv_ena   [i] ),
                .wea            (tagv_wea   [i] ),
                .addra          (tagv_addra [i] ),
                .dina           (tagv_dina  [i] ),
                .douta          (tagv_douta [i] )
            );

            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 128           )
            ) u_data_sram(
                .clka           (clock          ),
                .ena            (data_ena   [i] ),
                .wea            (data_wea   [i] ),
                .addra          (data_addra [i] ),
                .dina           (data_dina  [i] ),
                .douta          (data_douta [i] )
            );
        end
    endgenerate
    `else

    `endif

    // cache control

    wire    [ 7:0]                      cache_idx =
        ({8{state_is_idle & !cacop_en}}         & araddr[11:4]) |
        ({8{state_is_idle &  cacop_en}}         & cacop_addr[11:4]) |
        ({8{state_is_receive | state_is_cacop}} & request_buffer_idx);
    wire    [$clog2(ICACHE_WAY)-1:0]    cache_way = 
        ({$clog2(ICACHE_WAY){state_is_idle}}    & cacop_addr[$clog2(ICACHE_WAY)-1:0]) |
        ({$clog2(ICACHE_WAY){state_is_cacop}}   & request_buffer_cacop_way);
    wire    [ICACHE_WAY-1:0]            replace_way_en;
    // assume ICACHE_WAY == 2
    replace_lru_2 u_replace(
        .clock      (clock),
        .reset      (reset),
        .en         (state_is_receive && receive_finish),
        .valid_way  (lookup_way_v_result),
        .lru_in     (lru[cache_idx]),
        .replace_en (replace_way_en)
    );

    wire    tagv_ena_i = 
        (state_is_idle && valid) || 
        (state_is_receive && receive_finish) ||
        (state_is_cacop);
    wire    [20:0] tagv_dina_i = 
        (state_is_receive) ? {request_buffer_tag, 1'b1} : 21'b0; 
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = tagv_ena_i;
            assign tagv_wea[i] = 
                (state_is_idle && cacop_en && (cache_way == i) &&(
                    idle_cacop_is_init || 
                    idle_cacop_is_index
                )) ||
                (state_is_receive && receive_finish && replace_way_en[i]) ||
                (state_is_cacop && lookup_way_hit[i]);
            assign tagv_addra[i] = cache_idx;
            assign tagv_dina[i] = tagv_dina_i;
        end
    endgenerate

    wire data_ena_i =
        (state_is_idle && valid && !cacop_en) || 
        (state_is_receive && receive_finish && !request_buffer_uncached) ||
        (state_is_cacop);
    wire data_wea_i = state_is_receive && receive_finish && !request_buffer_uncached;
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign data_ena[i] = data_ena_i;
            assign data_wea[i] = data_wea_i && replace_way_en[i];
            assign data_addra[i] = cache_idx;
            assign data_dina[i] = receive_result;
        end
    endgenerate
endmodule

module icache_v5(
    input           clock,
    input           reset,

    // common control (c) channel
    input           valid,      // in cpu, valid no dep on ready;
    output          ready,      // in cache, ready can dep on valid
    /// cpu ifetch
    //// read address (ar) channel
    /* verilator lint_off UNUSED */
    input   [31:0]  araddr,
    /* verilator lint_on UNUSED */
    input           uncached,
    //// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    output          rhit,
    /// cpu cacop
    input           cacop_valid,
    output          cacop_ready,
    input   [ 1:0]  cacop_code, // code[4:3]
    /* verilator lint_off UNUSED */
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */
    
    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data
    );

    localparam  ICACHE_WAY = 2;
    genvar i;   // way
    integer j;  // way

    // cache ports

    wire            tagv_ena    [0:ICACHE_WAY-1];
    wire            tagv_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:ICACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:ICACHE_WAY-1];

    wire            data_ena    [0:ICACHE_WAY-1];
    wire            data_wea    [0:ICACHE_WAY-1];
    wire    [ 7:0]  data_addra  [0:ICACHE_WAY-1];
    wire   [127:0]  data_dina   [0:ICACHE_WAY-1];
    wire   [127:0]  data_douta  [0:ICACHE_WAY-1];

    // request buffer
    reg     [19:0]  request_buffer_tag;
    reg     [ 7:0]  request_buffer_idx;
    reg             request_buffer_uncached;
    /// request type
    wire cacop_is_init = cacop_code == 2'd0;
    wire cacop_is_index = cacop_code == 2'd1;
    wire cacop_is_lookup = cacop_code == 2'd2;
    wire req_cacop_init = cacop_valid && cacop_is_init;
    wire req_cacop_index = cacop_valid && cacop_is_index;
    wire req_cacop_lookup = cacop_valid && cacop_is_lookup;
    wire req_read = !cacop_valid && valid && !uncached;
    wire req_read_uncached = !cacop_valid && valid && uncached;

    // state machine

    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_request = 2;
    localparam      state_receive = 3;
    localparam      state_cacop = 4;
    localparam      state_reset = 5;
    reg     [ 3:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    wire state_is_request = state == state_request;
    wire state_is_receive = state == state_receive;
    wire state_is_cacop = state == state_cacop;
    /// lookup
    wire [ICACHE_WAY-1:0]   lookup_way_v;
    reg  [ICACHE_WAY-1:0]   lookup_way_v_r;
    wire    [19:0]          lookup_way_tag  [0:ICACHE_WAY-1];
    wire [ICACHE_WAY-1:0]   lookup_way_hit;
    wire                    lookup_hit;
    reg    [127:0]          lookup_hit_data; // combinational logic
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign lookup_way_v[i] = tagv_douta[i][20];
            assign lookup_way_tag[i] = tagv_douta[i][19:0];
            assign lookup_way_hit[i] =
                lookup_way_v[i] && (lookup_way_tag[i] == request_buffer_tag);
        end
    endgenerate
    assign lookup_hit = |lookup_way_hit;
    always @(*) begin
        lookup_hit_data = 128'b0;
        for (j = 0; j < ICACHE_WAY; j = j + 1) begin
            lookup_hit_data = lookup_hit_data |
                ({128{lookup_way_hit[j]}} & data_douta[j]);
        end
    end
    wire lookup_ret = state_is_lookup && lookup_hit;

    /// receive
    reg     [31:0]  receive_buffer      [ 0:2];
    reg     [ 1:0]  receive_buffer_cnt;
    wire            receive_finish;
    wire   [127:0]  receive_result;
    assign receive_finish = ret_valid && (ret_last | (receive_buffer_cnt == 2'd3));
    assign receive_result = {ret_data, receive_buffer[2], receive_buffer[1], receive_buffer[0]};
    wire receive_ret = state_is_receive && receive_finish;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: begin
                if (req_cacop_lookup) begin
                    state <= state_cacop;
                    request_buffer_idx <= cacop_addr[11:4];
                    request_buffer_tag <= cacop_addr[31:12];
                end else begin
                    request_buffer_idx <= araddr[11:4];
                    request_buffer_tag <= araddr[31:12];                    
                    request_buffer_uncached <= uncached;
                    if (req_read) begin
                        state <= state_lookup;
                    end else if (req_read_uncached) begin
                        if (rd_rdy) begin
                            state <= state_receive;
                            receive_buffer_cnt <= 0;
                        end else begin
                            state <= state_request;
                        end
                    end
                end
            end
            state_lookup: begin
                if (lookup_hit) begin
                    if (cacop_valid || !valid) begin
                        state <= state_idle;
                    end else begin
                        request_buffer_idx <= araddr[11:4];
                        request_buffer_tag <= araddr[31:12];
                        request_buffer_uncached <= uncached;                            
                        if (req_read) begin
                            state <= state_lookup;
                        end else if (req_read_uncached) begin
                            if (rd_rdy) begin
                                state <= state_receive;
                                receive_buffer_cnt <= 0;
                            end else begin
                                state <= state_request;
                            end
                        end else begin // ?
                            state <= state_idle;
                        end
                    end
                end else begin
                    lookup_way_v_r <= lookup_way_v;
                    if (rd_rdy) begin
                        state <= state_receive;
                        receive_buffer_cnt <= 0;
                    end else begin
                        state <= state_request;
                    end
                end
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    receive_buffer_cnt <= 0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (receive_finish) begin
                        if (cacop_valid || !valid) begin
                            state <= state_idle;
                        end else begin
                            if (req_read) begin
                                state <= state_idle;
                            end else if (req_read_uncached) begin
                                request_buffer_idx <= araddr[11:4];
                                request_buffer_tag <= araddr[31:12];
                                request_buffer_uncached <= uncached;
                                if (rd_rdy) begin
                                    state <= state_receive;
                                    receive_buffer_cnt <= 0;
                                end else begin
                                    state <= state_request;
                                end        
                            end else begin // ?
                                state <= state_idle;
                            end
                        end
                    end else begin
                        receive_buffer[receive_buffer_cnt] <= ret_data;
                        receive_buffer_cnt <= receive_buffer_cnt + 1;
                    end
                end
            end
            state_cacop: begin
                state <= state_idle;
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end

    // i/o
    assign ready =
        (state_is_idle && !cacop_valid) ||
        (state_is_lookup && lookup_hit && !cacop_valid) ||
        (state_is_receive && receive_finish && req_read_uncached);
    assign rvalid = lookup_ret || receive_ret;
    assign rdata = 
        ({128{lookup_ret}} & lookup_hit_data) |
        ({128{receive_ret}} & receive_result);
    assign rhit = state_is_lookup && lookup_hit;
    assign cacop_ready = state_is_idle;
    assign rd_req = 
        (state_is_idle && req_read_uncached) ||
        (state_is_lookup && (
            ( lookup_hit && req_read_uncached) ||
            (!lookup_hit)
         )
        ) ||
        (state_is_request) ||
        (state_is_receive && receive_finish && req_read_uncached);
    assign rd_type = 3'b100;
    // tricky
    assign rd_addr = 
        ((state_is_lookup && !lookup_hit) || (state_is_request)) ?
            {request_buffer_tag, request_buffer_idx, 4'd0} :
            {araddr[31:4], 4'd0};


    // cache sram

    `ifdef TEST
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                // [20:1] tag   [0:0] v
                .DATA_WIDTH     ( 21            )
            ) u_tagv_sram(
                .clka           (clock          ),
                .ena            (tagv_ena   [i] ),
                .wea            (tagv_wea   [i] ),
                .addra          (tagv_addra [i] ),
                .dina           (tagv_dina  [i] ),
                .douta          (tagv_douta [i] )
            );

            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 128           )
            ) u_data_sram(
                .clka           (clock          ),
                .ena            (data_ena   [i] ),
                .wea            (data_wea   [i] ),
                .addra          (data_addra [i] ),
                .dina           (data_dina  [i] ),
                .douta          (data_douta [i] )
            );
        end
    endgenerate
    `else

    `endif

    // cache control

    //  ({8{state_is_idle && (req_cacop_lookup || req_read)}} & araddr[11:4]) |
    //  ({8{state_is_lookup && !lookup_hit && req_read}} & araddr[11:4]) |
    //  ({8{state_is_receive}} & request_buffer_idx) |
    //  ({8{state_is_cacop}} & request_buffer_idx);
    wire    [ 7:0]          cache_idx = 
        ({8{state_is_idle || state_is_lookup}} & araddr[11:4]) |
        ({8{state_is_receive || state_is_cacop}} & request_buffer_idx);
    wire [ICACHE_WAY-1:0]   replace_way_en;
    // assume ICACHE_WAY == 2
    replace_rand_2 u_replace(
        .clock      (clock),
        .reset      (reset),
        .en         (state_is_receive && receive_finish && !request_buffer_uncached),
        .valid_way  (lookup_way_v_r),
        .replace_en (replace_way_en)
    );

    wire    [20:0]          tagv_dina_i =
        (state_is_receive) ? {1'b1, request_buffer_tag} : 21'b0;
    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = 1'b1;
            assign tagv_wea[i] = 
                (state_is_idle && 
                    (req_cacop_init || req_cacop_index) && cacop_addr[1:0] == i) ||
                (state_is_receive && receive_finish &&
                    (!request_buffer_uncached && replace_way_en[i])) ||
                (state_is_cacop && lookup_way_hit[i]);
            assign tagv_addra[i] = cache_idx;
            assign tagv_dina[i] = tagv_dina_i;
        end
    endgenerate

    generate
        for (i = 0; i < ICACHE_WAY; i = i + 1) begin
            assign data_ena[i] = 1'b1;
            assign data_wea[i] =
                (state_is_receive && receive_finish &&
                    !request_buffer_uncached && replace_way_en[i]);
            assign data_addra[i] = cache_idx;
            assign data_dina[i] = receive_result;
        end
    endgenerate
endmodule
