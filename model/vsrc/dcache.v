/* verilator lint_off DECLFILENAME */

`default_nettype wire

module dcache_dummy (
    input           clock,
    input           reset,

    // cpu load / store
    /// common control (c) channel
    input           valid,
    output          ready,
    input           op,         // 0: read, 1: write
    input   [31:0]  addr,
    input   [ 3:0]  strb,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    output          rhit,
    /// write data (w) channel
    input   [31:0]  wdata,
    output          whit,
    /* verilator lint_off UNUSED */
    input           cacop_valid,
    output          cacop_ready,
    input   [ 1:0]  cacop_code, // code[4:3]
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data,
    output          wr_req,
    output  [ 2:0]  wr_type,
    output  [31:0]  wr_addr,
    output  [ 3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);
    localparam  state_idle = 0;
    localparam  state_request = 1;  // wait axi rd_rdy | wr_rdy
    localparam  state_receive = 2;
    localparam  state_reset = 3;
    reg     [ 3:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_request = state == state_request;
    wire state_is_receive = state == state_receive;

    reg             req_op;
    reg     [31:0]  req_addr;
    reg     [ 3:0]  req_strb;
    reg     [31:0]  req_wdata;
    
    assign ready = state_is_idle;
    assign rvalid = state_is_receive && ret_valid && ret_last;
    assign rdata = ret_data;
    assign cacop_ready = 1'b1;
    wire request_is_read = (state_is_request && !req_op);
    wire request_is_write = (state_is_request && req_op);
    assign rd_req = request_is_read;
    assign rd_type = 3'b010;
    assign rd_addr = {{30{request_is_read}}, 2'b0} & req_addr;
    assign wr_req = request_is_write;
    assign wr_type = 3'b010;
    assign wr_addr = {{30{request_is_write}}, 2'b0} & req_addr;
    assign wr_wstrb = req_strb;
    assign wr_data = {96'b0, req_wdata};

    assign rhit = 1'b0;
    assign whit = 1'b0;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
            req_op <= 0;
            req_addr <= 0;
            req_strb <= 0;
            req_wdata <= 0;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    req_op <= op;
                    req_addr <= addr;
                    if (op) begin
                        req_strb <= strb;
                        req_wdata <= wdata;
                    end
                    state <= state_request;
                end
            end
            state_request: begin
                if (req_op) begin
                    if (wr_rdy) begin
                        state <= state_idle;
                    end
                end else begin
                    if (rd_rdy) begin
                        state <= state_receive;
                    end
                end
            end
            state_receive: begin
                if (ret_valid && ret_last) begin
                    state <= state_idle;
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule

module dcache_dummy_v2 (
    input           clock,
    input           reset,

    // cpu load / store
    /// common control (c) channel
    input           valid,
    output          ready,
    input           op,         // 0: read, 1: write
    input   [31:0]  addr,
    input   [ 3:0]  strb,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    output          rhit,
    /// write data (w) channel
    input   [31:0]  wdata,
    output          whit,
    /* verilator lint_off UNUSED */
    input           cacop_valid,
    output          cacop_ready,
    input   [ 1:0]  cacop_code, // code[4:3]
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data,
    output          wr_req,
    output  [ 2:0]  wr_type,
    output  [31:0]  wr_addr,
    output  [ 3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);
    localparam  state_idle = 0;
    localparam  state_receive = 1;
    localparam  state_reset = 2;
    reg     [ 3:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_receive = state == state_receive;
    wire state_can_accept_request;

    wire receive_finish;
    assign receive_finish = state_is_receive && ret_valid && ret_last;
    assign state_can_accept_request = (state_is_idle || receive_finish);

    //  (state_is_idle && (
    //      (!cacop_en && (
    //          ( op && wr_rdy) ||
    //          (!op && rd_rdy)
    //      )) ||
    //      ( cacop_en)
    //  )) ||
    //  (state_is_receive && ret_last && (
    //      (!cacop_en && (
    //          ( op && wr_rdy) ||
    //          (!op && rd_rdy)
    //      )) ||
    //      ( cacop_en)
    //  ))
    assign ready = 
        state_can_accept_request && 
        ((op && wr_rdy) || (!op && rd_rdy));
    assign rvalid = receive_finish;
    assign rdata = ret_data;
    //  (state_is_idle && valid && !op) ||
    //  (state_is_receive && receive_finish && valid && !op);
    assign rd_req = 
        state_can_accept_request && valid && !op;
    assign rd_type = 3'b010;
    assign rd_addr = {{30{1'b1}}, 2'b0} & addr;
    //  (state_is_idle && valid && op) ||
    //  (state_is_receive && receive_finish && valid && op);
    assign wr_req = 
        state_can_accept_request && valid && op;
    assign wr_type = 3'b010;
    assign wr_addr = {{30{1'b1}}, 2'b0} & addr;
    assign wr_wstrb = strb;
    assign wr_data = {96'b0, wdata};

    assign rhit = 1'b0;
    assign whit = 1'b0;

    assign cacop_ready = 1'b1;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: 
            // begin
            //     if (valid) begin
            //         if (op) begin
            //             if (wr_rdy) begin
            //                 state <= state_idle;
            //             end                            
            //         end else begin
            //             if (rd_rdy) begin
            //                 state <= state_receive;
            //             end
            //         end                       
            //     end
            // end
            begin
                if (valid) begin
                    if (!op && rd_rdy) begin
                        state <= state_receive;
                    end
                end
            end
            state_receive: begin
                if (ret_valid && ret_last) begin
                    state <= state_idle;
                    if (valid) begin
                        if (op) begin
                            if (wr_rdy) begin
                                state <= state_idle;
                            end
                        end else begin
                            if (rd_rdy) begin
                                state <= state_receive;
                            end
                        end                       
                    end else begin
                        state <= state_idle;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule

module dcache_dummy_v3 (
    input           clock,
    input           reset,

    // cpu load / store
    /// common control (c) channel
    input           valid,
    output          ready,
    input           op,         // 0: read, 1: write
    input   [31:0]  addr,
    input   [ 3:0]  strb,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    output          rhit,
    /// write data (w) channel
    input   [31:0]  wdata,
    output          whit,
    /* verilator lint_off UNUSED */
    input           cacop_valid,
    output          cacop_ready,
    input   [ 1:0]  cacop_code, // code[4:3]
    input   [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [31:0]  ret_data,
    output          wr_req,
    output  [ 2:0]  wr_type,
    output  [31:0]  wr_addr,
    output  [ 3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);
    localparam  state_idle = 0;
    localparam  state_receive = 1;
    localparam  state_reset = 2;
    reg     [ 3:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_receive = state == state_receive;
    wire state_can_accept_request;

    wire receive_finish;
    assign receive_finish = state_is_receive && ret_valid && ret_last;
    assign state_can_accept_request = (state_is_idle || receive_finish);

    wire    [ 2:0]  size;
    strb2size u_strb2size(
        .strb   ( strb          ),
        .off    ( addr[ 1:0]    ),
        .size   ( size          )
    );

    assign ready = 
        state_can_accept_request && 
        ((op && wr_rdy) || (!op && rd_rdy));
    assign rvalid = receive_finish;
    assign rdata = ret_data;
    assign rd_req = 
        state_can_accept_request && valid && !op;
    assign rd_type = size;
    assign rd_addr = addr;
    assign wr_req = 
        state_can_accept_request && valid && op;
    assign wr_type = size;
    assign wr_addr = addr;
    assign wr_wstrb = strb;
    assign wr_data = {96'b0, wdata};

    assign rhit = 1'b0;
    assign whit = 1'b0;

    assign cacop_ready = 1'b1;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    if (!op && rd_rdy) begin
                        state <= state_receive;
                    end
                end
            end
            state_receive: begin
                if (ret_valid && ret_last) begin
                    state <= state_idle;
                    if (valid) begin
                        if (op) begin
                            if (wr_rdy) begin
                                state <= state_idle;
                            end
                        end else begin
                            if (rd_rdy) begin
                                state <= state_receive;
                            end
                        end                       
                    end else begin
                        state <= state_idle;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule

module dcache_v1(
    input               clock,
    input               reset,

    // cpu load / store
    /// common control (c) channel
    input               valid,
    output              ready,
    input               op,         // 0: read, 1: write
    /* verilator lint_off UNUSED */
    input       [31:0]  addr,
    input       [ 3:0]  strb,
    input               uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output              rvalid,
    output      [31:0]  rdata,
    output              rhit,
    /// write data (w) channel
    input       [31:0]  wdata,
    output              whit,
    /* verilator lint_off UNUSED */
    input               cacop_valid,
    output              cacop_ready,
    input       [ 1:0]  cacop_code, // code[4:3]
    input       [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output              rd_req,
    output      [ 2:0]  rd_type,
    output      [31:0]  rd_addr,
    input               rd_rdy,
    input               ret_valid,
    input               ret_last,
    input       [31:0]  ret_data,
    output              wr_req,
    output      [ 2:0]  wr_type,
    output      [31:0]  wr_addr,
    output      [ 3:0]  wr_wstrb,
    output reg [127:0]  wr_data,
    input               wr_rdy
    );

    /* verilator lint_off UNUSED */
    genvar i; // way
    genvar j;
    integer k; // way
    integer t; // bank
    /* verilator lint_on UNUSED */

    // cache ports

    wire            tagv_ena;
    wire            tagv_wea;
    wire    [ 7:0]  tagv_addra;
    wire    [20:0]  tagv_dina;
    wire    [20:0]  tagv_douta;

    wire            data_ena    [ 0:3];
    wire    [ 3:0]  data_wea    [ 0:3];
    wire    [ 7:0]  data_addra  [ 0:3];
    wire    [31:0]  data_dina   [ 0:3];
    wire    [31:0]  data_douta  [ 0:3];

    reg     [ 0:0]  dirt    [0:255];
    wire            dirt_wea;
    wire    [ 7:0]  dirt_addra;
    wire            dirt_dina;

    always @(posedge clock) begin
        if (dirt_wea) begin
            dirt[dirt_addra] <= dirt_dina;
        end
    end


    // buffers
    /// req_buf
    reg             req_buf_op;
    reg     [19:0]  req_buf_tag;
    reg     [ 7:0]  req_buf_idx;
    reg     [ 1:0]  req_buf_bank;
    reg     [ 3:0]  req_buf_awstrb;
    reg     [31:0]  req_buf_wdata;
    wire    [31:0]  req_buf_line_addr =
        {req_buf_tag, req_buf_idx, 4'b0};

    /// wr_buf
    reg     [ 7:0]  wr_buf_idx;
    reg     [ 1:0]  wr_buf_bank;
    reg     [ 3:0]  wr_buf_awstrb;
    reg     [31:0]  wr_buf_wdata;

    /// hit_buf

    /// recv_buf
    reg     [31:0]  recv_buf        [ 0:2];
    reg     [ 1:0]  recv_cnt;


    // Main State Machine
    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_reqw = 2;
    localparam      state_send = 3;
    localparam      state_reqr = 4;
    localparam      state_recv = 5;
    localparam      state_reset = 6;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    // wire state_is_reqw = state == state_reqw;
    wire state_is_send = state == state_send;
    wire state_is_reqr = state == state_reqr;
    wire state_is_recv = state == state_recv;

    wire cache_sram_rw_collision;
    assign cache_sram_rw_collision = 
        (wr_buf_state_is_write && wr_buf_bank == addr[3:2]);

    /// idle
    /// lookup
    wire                lookup_hit;
    wire    [31:0]      lookup_hit_data;
    wire                lookup_need_replace;
    wire                lookup_line_v;
    wire    [19:0]      lookup_line_tag;
    wire                lookup_line_d;
    assign lookup_hit = lookup_line_v && (req_buf_tag == lookup_line_tag);
    assign lookup_hit_data = data_douta[req_buf_bank];
    assign {lookup_line_v, lookup_line_tag} = tagv_douta;
    assign lookup_line_d = 
        (state_is_lookup && lookup_hit && wr_buf_state_is_write && wr_buf_idx == req_buf_idx && wr_buf_bank == req_buf_bank) ?
            1'b1 : dirt[req_buf_idx];
    wire lookup_ret = state_is_lookup && lookup_hit && !req_buf_op;
    assign lookup_need_replace = !lookup_hit && lookup_line_v && lookup_line_d;
    /// receive
    wire                recv_fin;
    assign recv_fin = ret_valid && (ret_last || recv_cnt == 2'd3);
    wire recv_ret = state_is_recv && recv_fin;
    wire    [31:0]      recv_res    [ 0:3];
    generate
        for (j = 0; j < 3; j = j + 1) begin
            wstrb_mixer u_receive_ret(
                .en     ( req_buf_op && req_buf_bank == j   ),
                .x      ( req_buf_wdata                     ),
                .y      ( recv_buf[j]                       ),
                .wstrb  ( req_buf_awstrb                    ),
                .f      ( recv_res[j]                       )
            );
        end
    endgenerate
    wstrb_mixer u_receive_ret(
        .en     ( req_buf_op && req_buf_bank == 2'd3),
        .x      ( req_buf_wdata                     ),
        .y      ( ret_data                          ),
        .wstrb  ( req_buf_awstrb                    ),
        .f      ( recv_res[3]                       )
    );

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    if (cache_sram_rw_collision) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;

                            {req_buf_op, req_buf_tag, req_buf_idx, req_buf_bank}
                        <=  {op        , addr[31:12], addr[11:4] , addr[3:2]};
                        if (op) begin
                            req_buf_awstrb <= strb;
                            req_buf_wdata <= wdata;
                        end
                    end
                end
            end 
            state_lookup: begin
                if (lookup_hit) begin
                    if (!valid || cache_sram_rw_collision) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;

                            {req_buf_op, req_buf_tag, req_buf_idx, req_buf_bank}
                        <=  {op        , addr[31:12], addr[11:4] , addr[3:2]};
                        if (op) begin
                            req_buf_awstrb <= strb;
                            req_buf_wdata <= wdata;
                        end
                    end
                end else begin
                    if (lookup_need_replace) begin
                        state <= state_reqw;
                    end else begin
                        state <= state_reqr;
                    end
                end
            end
            state_reqw: begin
                if (wr_rdy) begin
                    state <= state_send;
                end
            end
            state_send: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end else begin
                    state <= state_reqr;
                end
            end
            state_reqr: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end
            end
            state_recv: begin
                if (ret_valid) begin
                    if (recv_fin) begin
                        state <= state_idle;                                                
                    end else begin
                        recv_buf[recv_cnt] <= ret_data;
                        recv_cnt <= recv_cnt + 1;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
    

    // Write Buffer State Machine
    localparam  wr_buf_state_idle = 0;
    localparam  wr_buf_state_write = 1;
    reg         wr_buf_state;
    // wire wr_buf_state_is_idle = wr_buf_state == wr_buf_state_idle;
    wire wr_buf_state_is_write = wr_buf_state == wr_buf_state_write;
    wire wr_buf_accept_req = state_is_lookup && lookup_hit && req_buf_op;
    always @(posedge clock) begin
        if (reset) begin
            wr_buf_state <= wr_buf_state_idle;
        end else case (wr_buf_state)
            wr_buf_state_idle: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_idx,  wr_buf_bank,  wr_buf_awstrb,  wr_buf_wdata}
                    <=  {req_buf_idx, req_buf_bank, req_buf_awstrb, req_buf_wdata};
                end                
            end 
            wr_buf_state_write: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_idx,  wr_buf_bank,  wr_buf_awstrb,  wr_buf_wdata}
                    <=  {req_buf_idx, req_buf_bank, req_buf_awstrb, req_buf_wdata};
                end else begin
                    wr_buf_state <= wr_buf_state_idle;
                end
            end
            default: begin
                wr_buf_state <= wr_buf_state_idle;
            end
        endcase
    end

    // i/o
    assign ready = 
        (state_is_idle && !cache_sram_rw_collision) ||
        (state_is_lookup && lookup_hit && !cache_sram_rw_collision);
    assign rvalid = (lookup_ret || recv_ret) && !req_buf_op;
    wire    [31:0]  wr_buf_fwd;
    wstrb_mixer u_lookup_ret(
        .en     ( 1'b1              ),
        .x      ( wr_buf_wdata      ),
        .y      ( lookup_hit_data   ),
        .wstrb  ( wr_buf_awstrb     ),
        .f      ( wr_buf_fwd        )
    );
    assign rdata = 
        (state_is_lookup && lookup_hit && wr_buf_state_is_write && wr_buf_idx == req_buf_idx && wr_buf_bank == req_buf_bank) ?
            wr_buf_fwd : (
                ({32{lookup_ret}} & lookup_hit_data) |
                ({32{recv_ret}} & recv_res[req_buf_bank])
            );
    assign rhit = (state_is_lookup && !req_buf_op && lookup_hit);
    assign whit = (state_is_lookup &&  req_buf_op && lookup_hit);
    assign cacop_ready = 1'b0;
    assign rd_req = 
        (state_is_send) ||
        (state_is_reqr);
    assign rd_type = 3'b100;
    assign rd_addr = req_buf_line_addr;
    assign wr_req = 
        (state_is_send);
    assign wr_type = 3'b100;
    assign wr_addr = {lookup_line_tag, req_buf_idx, 4'd0};
    assign wr_wstrb = 4'hf;
    always @(*) begin
        for (t = 0; t < 4; t = t + 1) begin
            wr_data[t*32 +: 32] = data_douta[t];
        end
    end

    // cache sram

    `ifdef TEST

    sram_sim #(
        .ADDR_WIDTH     ( 8             ),
        .DATA_WIDTH     ( 21            )
        // v [20], tag [19:0]
    ) u_tagv_sram(
        .clka           ( clock         ),
        .ena            ( tagv_ena      ),
        .wea            ( tagv_wea      ),
        .addra          ( tagv_addra    ),
        .dina           ( tagv_dina     ),
        .douta          ( tagv_douta    )
    );

    generate
        for (j = 0; j < 4; j = j + 1) begin
            sram_sim_strb #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 32            )
            ) u_data_sram(
                .clka           ( clock         ),
                .ena            ( data_ena[j]   ),
                .wea            ( data_wea[j]   ),
                .addra          ( data_addra[j] ),
                .dina           ( data_dina[j]  ),
                .douta          ( data_douta[j] )
            );
        end
    endgenerate

    `else

    `endif

    // cache control

    assign tagv_ena = 1'b1;
    assign tagv_wea = 
        (state_is_recv && recv_fin);
    assign tagv_addra =
        (state_is_idle || (state_is_lookup && lookup_hit)) ? addr[11:4] : req_buf_idx;
    assign tagv_dina =
        {1'b1, req_buf_tag};
    
    generate
        for (j = 0; j < 4; j = j + 1) begin
            assign data_ena[j] = 1'b1;
            assign data_wea[j] = 
                ({4{wr_buf_state_is_write && wr_buf_bank == j}} & wr_buf_awstrb) |
                ({4{state_is_recv && recv_fin}});
            assign data_addra[j] = 
                (wr_buf_state_is_write && wr_buf_bank == j) ? 
                    (wr_buf_idx) : (
                        (state_is_idle || (state_is_lookup && lookup_hit)) ? addr[11:4] : req_buf_idx
                    );
            assign data_dina[j] = 
                (wr_buf_state_is_write && wr_buf_bank == j) ?
                    wr_buf_wdata : recv_res[j];
        end
    endgenerate

    assign dirt_wea = (wr_buf_state_is_write) || (recv_ret);
    assign dirt_addra = 
        (wr_buf_state_is_write) ? wr_buf_idx : req_buf_idx;
    assign dirt_dina = 
        (wr_buf_state_is_write) ? 1'b1 : 
        (req_buf_op);
endmodule

module dcache_v2(
    input               clock,
    input               reset,

    // cpu load / store
    /// common control (c) channel
    input               valid,
    output              ready,
    input               op,         // 0: read, 1: write
    input       [31:0]  addr,
    input       [ 3:0]  strb,
    /* verilator lint_off UNUSED */
    input               uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output              rvalid,
    output      [31:0]  rdata,
    output              rhit,
    /// write data (w) channel
    input       [31:0]  wdata,
    output              whit,
    /* verilator lint_off UNUSED */
    input               cacop_valid,
    output              cacop_ready,
    input       [ 1:0]  cacop_code, // code[4:3]
    input       [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output              rd_req,
    output      [ 2:0]  rd_type,
    output      [31:0]  rd_addr,
    input               rd_rdy,
    input               ret_valid,
    input               ret_last,
    input       [31:0]  ret_data,
    output              wr_req,
    output      [ 2:0]  wr_type,
    output      [31:0]  wr_addr,
    output      [ 3:0]  wr_wstrb,
    output reg [127:0]  wr_data,
    input               wr_rdy
    );

    parameter DCACHE_WAY = 1;

    genvar i; // way
    genvar j;
    integer k; // way
    integer t; // bank

    // cache ports

    wire            tagv_ena    [0:DCACHE_WAY-1];
    wire            tagv_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:DCACHE_WAY-1];

    wire            data_ena    [0:DCACHE_WAY-1][ 0:3];
    wire            data_wea    [0:DCACHE_WAY-1][ 0:3];
    wire    [ 7:0]  data_addra  [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_dina   [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_douta  [0:DCACHE_WAY-1][ 0:3];

    reg             dirt        [0:DCACHE_WAY-1][0:255];
    wire            dirt_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addra  [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addrb  [0:DCACHE_WAY-1];
    wire            dirt_dina   [0:DCACHE_WAY-1];
    wire            dirt_doutb  [0:DCACHE_WAY-1];

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            always @(posedge clock) begin
                if (dirt_wea[i]) begin
                    dirt[i][dirt_addra[i]] <= dirt_dina[i];
                end
            end
            assign dirt_doutb[i] = dirt[i][dirt_addrb[i]];
        end
    endgenerate

    // request
    /* verilator lint_off UNUSED */
    wire    [19:0]  req_tag = addr[31:12];
    wire    [ 7:0]  req_idx = addr[11:4];
    wire    [ 1:0]  req_bank = addr[3:2];
    wire    [ 1:0]  req_off = addr[1:0];
    /* verilator lint_on UNUSED */
    assign {req_tag, req_idx, req_bank, req_off} = addr;
    // wire req_is_r = !op;
    // wire req_is_w =  op;


    // buffers
    /// req_buf
    reg             req_buf_op;
    reg     [31:0]  req_buf_addr;
    reg     [ 3:0]  req_buf_awstrb;
    reg     [31:0]  req_buf_wdata;
    wire    [19:0]  req_buf_tag;
    wire    [ 7:0]  req_buf_idx;
    wire    [ 3:2]  req_buf_bank;
    /* verilator lint_off UNUSED */
    wire    [ 1:0]  req_buf_off;
    /* verilator lint_on UNUSED */
    assign {req_buf_tag, req_buf_idx, req_buf_bank, req_buf_off} = req_buf_addr;
    // wire req_buf_is_r = !req_buf_op;
    // wire req_buf_is_w =  req_buf_op;

    /// wr_buf
    reg     [ 0:0]  wr_buf_way;
    reg     [19:0]  wr_buf_tag;
    reg     [ 7:0]  wr_buf_idx;
    reg     [ 1:0]  wr_buf_bank;
    reg     [31:0]  wr_buf_wdata;

    /// hit_buf

    /// recv_buf
    reg     [31:0]  recv_buf        [ 0:2];
    reg     [ 1:0]  recv_cnt;


    // Main State Machine
    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_reqw = 2;
    localparam      state_send = 3;
    localparam      state_reqr = 4;
    localparam      state_recv = 5;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    // wire state_is_reqw = state == state_reqw;
    wire state_is_send = state == state_send;
    wire state_is_reqr = state == state_reqr;
    wire state_is_recv = state == state_recv;

    wire cache_sram_rw_collision;
    assign cache_sram_rw_collision = 
        (valid && wr_buf_state_is_write && wr_buf_bank == req_bank);

    /// idle
    /// lookup
    wire [DCACHE_WAY-1:0]   lookup_way_v;
    wire    [19:0]          lookup_way_tag      [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_d;
    wire    [31:0]          lookup_way_data     [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_hit;
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign {lookup_way_v[i], lookup_way_tag[i], lookup_way_data[i]}
                =  {tagv_douta[i]                     , data_douta[i][req_buf_bank]};
            assign lookup_way_d[i] = (wr_buf_way == i && wr_buf_idx == req_buf_idx) ? 1'b1 : dirt_doutb[i];
            assign lookup_way_hit[i] = lookup_way_v[i] && (lookup_way_tag[i] == req_buf_tag);
            assign lookup_way_data[i] = data_douta[i][req_buf_bank];
        end
    endgenerate
    wire lookup_hit = |lookup_way_hit;
    reg      [31:0]  lookup_hit_data;    // combinational logic
    // assign lookup_hit_data = data_douta[0][req_buf_bank];
    always @(*) begin
        lookup_hit_data = 0;
        for (k = 0; k < DCACHE_WAY; k = k + 1) begin
            lookup_hit_data = lookup_hit_data |
                ({32{lookup_way_hit[k]}} & lookup_way_data[k]);
        end        
    end
    wire    [ 0:0]  lookup_miss_way_replace_en_w;
    reg     [ 0:0]  lookup_miss_way_replace_en;
    wire            lookup_miss_need_send;
    replace_1 u_replace(
        .clock          ( clock         ),
        .reset          ( reset         ),
        .en             ( 1'b1          ),
        .way_v          ( lookup_way_v  ),
        .way_d          ( lookup_way_d  ),
        .way_replace_en ( lookup_miss_way_replace_en_w ),
        .need_send      ( lookup_miss_need_send )
    );
    /// send
    // TODO: multiple ways
    wire    [19:0]  send_tag = tagv_douta[0][19:0];
    /// recv
    wire recv_fin = ret_valid && (ret_last || recv_cnt == 2'd3);
    wire    [31:0]  recv_res    [ 0:3];
    generate
        for (j = 0; j < 3; j = j + 1) begin
            assign recv_res[j] = recv_buf[j];
        end
        assign recv_res[3] = ret_data;
    endgenerate
    wire    [31:0]  recv_mixed  [ 0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin
            wstrb_mixer u_recv_mixer(
                .en     ( req_buf_op && req_buf_bank == j ),
                .x      ( req_buf_wdata     ),
                .y      ( recv_res[j]       ),
                .wstrb  ( req_buf_awstrb    ),
                .f      ( recv_mixed[j]     )
            );
        end
    endgenerate
    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            recv_buf[0] <= 0;
            recv_buf[1] <= 0;
            recv_buf[2] <= 0;
            req_buf_op <= 0;
            req_buf_addr <= 0;
            req_buf_awstrb <= 0;
            req_buf_wdata <= 0;
        end else case (state)
            state_idle: begin
                if (valid && !cache_sram_rw_collision) begin
                    state <= state_lookup;
                        {req_buf_op, req_buf_addr}
                    <=  {op,         addr};
                    if (op) begin
                            {req_buf_awstrb, req_buf_wdata}
                        <=  {strb,           wdata};
                    end
                end
            end 
            state_lookup: begin
                if (lookup_hit) begin
                    if (!valid || cache_sram_rw_collision) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;
                            {req_buf_op, req_buf_addr}
                        <=  {op,         addr};
                        if (op) begin
                                {req_buf_awstrb, req_buf_wdata}
                            <=  {strb,           wdata};
                        end
                    end
                end else begin
                    lookup_miss_way_replace_en <= lookup_miss_way_replace_en_w;
                    if (lookup_miss_need_send) begin
                        state <= state_reqw;
                    end else begin
                        state <= state_reqr;
                    end
                end
            end
            state_reqw: begin
                if (wr_rdy) begin
                    state <= state_send;
                end
            end
            state_send: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end else begin
                    state <= state_reqr;
                end
            end
            state_reqr: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end
            end
            state_recv: begin
                if (ret_valid) begin
                    if (recv_fin) begin
                        state <= state_idle;                        
                    end else begin
                        recv_buf[recv_cnt] <= ret_data;                        
                        recv_cnt <= recv_cnt + 1;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
    

    // Write Buffer State Machine
    localparam  wr_buf_state_idle = 0;
    localparam  wr_buf_state_write = 1;
    reg         wr_buf_state;
    // wire wr_buf_state_is_idle = wr_buf_state == wr_buf_state_idle;
    wire wr_buf_state_is_write = wr_buf_state == wr_buf_state_write;
    wire wr_buf_accept_req = state_is_lookup && lookup_hit && req_buf_op;
    /// wr_buf_idle
    wire    [31:0]  wr_buf_wdata_mixed;
    wstrb_mixer u_wr_buf_mixer(
        .en         ( 1'b1              ),
        .x          ( req_buf_wdata     ),
        .y          ( lookup_hit_data   ),
        .wstrb      ( req_buf_awstrb    ),
        .f          ( wr_buf_wdata_mixed)
    );
    always @(posedge clock) begin
        if (reset) begin
            wr_buf_state <= wr_buf_state_idle;
            wr_buf_way <= 0;
            wr_buf_tag <= 0;
            wr_buf_idx <= 0;
            wr_buf_bank <= 0;
            wr_buf_wdata <= 0;
        end else case (wr_buf_state)
            wr_buf_state_idle: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way, wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {1'b0      , req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end                
            end 
            wr_buf_state_write: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way, wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {1'b0      , req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end else begin
                    wr_buf_state <= wr_buf_state_idle;
                end
            end
            default: begin
                wr_buf_state <= wr_buf_state_idle;
            end
        endcase
    end

    // i/o
    assign ready = !cache_sram_rw_collision && (
        (state_is_idle) ||
        (state_is_lookup && lookup_hit)
    );
    assign rvalid = !req_buf_op && (
        (state_is_lookup && lookup_hit) ||
        (state_is_recv && ret_valid && recv_cnt == req_buf_bank)
    );
    assign rdata = 
        ({req_buf_tag, req_buf_idx, req_buf_bank} == {wr_buf_tag, wr_buf_idx, wr_buf_bank}) ?
            wr_buf_wdata : (
                ({32{state_is_lookup}} & lookup_hit_data) |
                ({32{state_is_recv}} & ret_data)
            );
    assign rhit = state_is_lookup && !req_buf_op && lookup_hit;
    assign whit = state_is_lookup &&  req_buf_op && lookup_hit;
    assign cacop_ready = 1'b0;

    assign rd_req = state_is_send || state_is_reqr;
    assign rd_type = 3'b100;
    assign rd_addr = {req_buf_tag, req_buf_idx, 4'b0};
    assign wr_req = state_is_send;
    assign wr_type = 3'b100;
    assign wr_addr = {send_tag, req_buf_idx, 4'b0};
    assign wr_wstrb = 4'hf;
    always @(*) begin
        wr_data = 128'b0;
        // TODO: mutiple ways
        for (t = 0; t < 4; t = t + 1) begin
            wr_data[t*32 +: 32] = data_douta[0][t];
        end
    end

    // cache sram

    `ifdef TEST

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 21            )
                // v [20], tag [19:0]
            ) u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                sram_sim #(
                    .ADDR_WIDTH     ( 8             ),
                    .DATA_WIDTH     ( 32            )
                ) u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate

    `else
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            dcache_tagv_sram u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                dcache_data_sram u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate


    `endif

    // cache control
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = 1'b1;
            assign tagv_wea[i] = 
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign tagv_addra[i] = 
                (state_is_idle)     ?   req_idx :
                (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                        req_buf_idx; 
            assign tagv_dina[i] =
                (state_is_recv)     ?   {1'b1, req_buf_tag} : 21'b0;
        end
    endgenerate
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                assign data_ena[i][j] = 1'b1;
                assign data_wea[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way == i && wr_buf_bank == j) ||
                    (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
                assign data_addra[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way == i && wr_buf_bank == j)  ?   wr_buf_idx :
                    (state_is_idle)     ?   req_idx :
                    (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                            req_buf_idx;
                assign data_dina[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way == i && wr_buf_bank == j)  ?   wr_buf_wdata :
                    (state_is_recv)     ?   recv_mixed[j] :
                                            32'b0;
            end
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign dirt_wea[i] = 
                (wr_buf_state_is_write && wr_buf_way == i) ||
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign dirt_addra[i] = 
                (wr_buf_state_is_write && wr_buf_way == i) ? wr_buf_idx : req_buf_idx;
            assign dirt_addrb[i] = req_buf_idx;
            assign dirt_dina[i] = 
                (wr_buf_state_is_write)         ?   1'b1 :
                (state_is_recv && req_buf_op)   ?   1'b1 : 
                                                    1'b0;
        end
    endgenerate
endmodule

module dcache_v3(
    input               clock,
    input               reset,

    // cpu load / store
    /// common control (c) channel
    input               valid,
    output              ready,
    input               op,         // 0: read, 1: write
    input       [31:0]  addr,
    input       [ 3:0]  strb,
    /* verilator lint_off UNUSED */
    input               uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output              rvalid,
    output      [31:0]  rdata,
    output              rhit,
    /// write data (w) channel
    input       [31:0]  wdata,
    output              whit,
    /* verilator lint_off UNUSED */
    input               cacop_valid,
    output              cacop_ready,
    input       [ 1:0]  cacop_code, // code[4:3]
    input       [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output              rd_req,
    output      [ 2:0]  rd_type,
    output      [31:0]  rd_addr,
    input               rd_rdy,
    input               ret_valid,
    input               ret_last,
    input       [31:0]  ret_data,
    output              wr_req,
    output      [ 2:0]  wr_type,
    output      [31:0]  wr_addr,
    output      [ 3:0]  wr_wstrb,
    // output reg [127:0]  wr_data,
    output     [127:0]  wr_data,
    input               wr_rdy
    );

    parameter DCACHE_WAY = 2;

    /* verilator lint_off UNUSED */
    genvar i; // way
    genvar j;
    integer k; // way
    integer t; // bank
    /* verilator lint_on UNUSED */

    // cache ports

    wire            tagv_ena    [0:DCACHE_WAY-1];
    wire            tagv_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:DCACHE_WAY-1];

    wire            data_ena    [0:DCACHE_WAY-1][ 0:3];
    wire            data_wea    [0:DCACHE_WAY-1][ 0:3];
    wire    [ 7:0]  data_addra  [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_dina   [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_douta  [0:DCACHE_WAY-1][ 0:3];

    reg             dirt        [0:DCACHE_WAY-1][0:255];
    wire            dirt_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addra  [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addrb  [0:DCACHE_WAY-1];
    wire            dirt_dina   [0:DCACHE_WAY-1];
    wire            dirt_doutb  [0:DCACHE_WAY-1];

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            always @(posedge clock) begin
                if (dirt_wea[i]) begin
                    dirt[i][dirt_addra[i]] <= dirt_dina[i];
                end
            end
            assign dirt_doutb[i] = dirt[i][dirt_addrb[i]];
        end
    endgenerate

    // request
    /* verilator lint_off UNUSED */
    wire    [19:0]  req_tag;
    wire    [ 7:0]  req_idx;
    wire    [ 1:0]  req_bank;
    wire    [ 1:0]  req_off;
    /* verilator lint_on UNUSED */
    assign {req_tag, req_idx, req_bank, req_off} = addr;
    // wire req_is_r = !op;
    // wire req_is_w =  op;


    // buffers
    /// req_buf
    reg             req_buf_op;
    reg     [31:0]  req_buf_addr;
    reg     [ 3:0]  req_buf_awstrb;
    reg     [31:0]  req_buf_wdata;
    wire    [19:0]  req_buf_tag;
    wire    [ 7:0]  req_buf_idx;
    wire    [ 1:0]  req_buf_bank;
    /* verilator lint_off UNUSED */
    wire    [ 1:0]  req_buf_off;
    /* verilator lint_on UNUSED */
    assign {req_buf_tag, req_buf_idx, req_buf_bank, req_buf_off} = req_buf_addr;
    // wire req_buf_is_r = !req_buf_op;
    // wire req_buf_is_w =  req_buf_op;

    /// wr_buf
    reg [DCACHE_WAY-1:0]    wr_buf_way;
    reg     [19:0]          wr_buf_tag;
    reg     [ 7:0]          wr_buf_idx;
    reg     [ 1:0]          wr_buf_bank;
    reg     [31:0]          wr_buf_wdata;

    /// hit_buf

    /// recv_buf
    reg     [31:0]  recv_buf        [ 0:2];
    reg     [ 1:0]  recv_cnt;


    // Main State Machine
    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_reqw = 2;
    localparam      state_send = 3;
    localparam      state_reqr = 4;
    localparam      state_recv = 5;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    // wire state_is_reqw = state == state_reqw;
    wire state_is_send = state == state_send;
    wire state_is_reqr = state == state_reqr;
    wire state_is_recv = state == state_recv;

    wire cache_sram_rw_collision;
    assign cache_sram_rw_collision = 
        (valid && wr_buf_state_is_write && (wr_buf_bank == req_bank));

    /// idle
    /// lookup
    wire [DCACHE_WAY-1:0]   lookup_way_v;
    wire    [19:0]          lookup_way_tag      [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_d;
    wire    [31:0]          lookup_way_data     [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_hit;
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign {lookup_way_v[i], lookup_way_tag[i], lookup_way_data[i]}
                =  {tagv_douta[i]                     , data_douta[i][req_buf_bank]};
            assign lookup_way_d[i] = (wr_buf_way[i] && wr_buf_idx == req_buf_idx) ? 1'b1 : dirt_doutb[i];
            assign lookup_way_hit[i] = lookup_way_v[i] && (lookup_way_tag[i] == req_buf_tag);
            assign lookup_way_data[i] = data_douta[i][req_buf_bank];
        end
    endgenerate
    wire lookup_hit = |lookup_way_hit;
    // assume 2 ways
    // reg      [31:0]  lookup_hit_data;    // combinational logic
    // assign lookup_hit_data = data_douta[0][req_buf_bank];
    // always @(*) begin
    //     lookup_hit_data = 0;
    //     for (k = 0; k < DCACHE_WAY; k = k + 1) begin
    //         lookup_hit_data = lookup_hit_data |
    //             ({32{lookup_way_hit[k]}} & lookup_way_data[k]);
    //     end        
    // end
    wire        [31:0]  lookup_hit_data;
    assign lookup_hit_data = 
        ({32{lookup_way_hit[0]}} & lookup_way_data[0]) |
        ({32{lookup_way_hit[1]}} & lookup_way_data[1]);

    wire [DCACHE_WAY-1:0]   lookup_miss_way_replace_en_w;
    reg  [DCACHE_WAY-1:0]   lookup_miss_way_replace_en;
    wire                    lookup_miss_need_send;
    replace_rand_2 u_replace(
        .clock          ( clock         ),
        .reset          ( reset         ),
        .en             ( 1'b1          ),
        .way_v          ( lookup_way_v  ),
        .way_d          ( lookup_way_d  ),
        .way_replace_en ( lookup_miss_way_replace_en_w ),
        .need_send      ( lookup_miss_need_send )
    );
    /// send
    // reg     [19:0]  send_tag; // combinational logic
    // always @(*) begin
    //     send_tag = 0;
    //     for (k = 0; k < DCACHE_WAY; k = k + 1) begin
    //         send_tag = send_tag | 
    //             ({20{lookup_miss_way_replace_en[k]}} & lookup_way_tag[k]);
    //     end
    // end
    wire        [19:0]  send_tag;
    assign send_tag = 
        ({20{lookup_miss_way_replace_en[0]}} & lookup_way_tag[0]) |
        ({20{lookup_miss_way_replace_en[1]}} & lookup_way_tag[1]);
    /// recv
    wire recv_fin = ret_valid && (ret_last || recv_cnt == 2'd3);
    wire    [31:0]  recv_res    [ 0:3];
    generate
        for (j = 0; j < 3; j = j + 1) begin
            assign recv_res[j] = recv_buf[j];
        end
        assign recv_res[3] = ret_data;
    endgenerate
    wire    [31:0]  recv_mixed  [ 0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin
            wstrb_mixer u_recv_mixer(
                .en     ( req_buf_op && req_buf_bank == j ),
                .x      ( req_buf_wdata     ),
                .y      ( recv_res[j]       ),
                .wstrb  ( req_buf_awstrb    ),
                .f      ( recv_mixed[j]     )
            );
        end
    endgenerate
    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            recv_buf[0] <= 0;
            recv_buf[1] <= 0;
            recv_buf[2] <= 0;
            req_buf_op <= 0;
            req_buf_addr <= 0;
            req_buf_awstrb <= 0;
            req_buf_wdata <= 0;
        end else case (state)
            state_idle: begin
                if (valid && !cache_sram_rw_collision) begin
                    state <= state_lookup;
                        {req_buf_op, req_buf_addr}
                    <=  {op,         addr};
                    if (op) begin
                            {req_buf_awstrb, req_buf_wdata}
                        <=  {strb,           wdata};
                    end
                end
            end 
            state_lookup: begin
                if (lookup_hit) begin
                    if (!valid || cache_sram_rw_collision) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;
                            {req_buf_op, req_buf_addr}
                        <=  {op,         addr};
                        if (op) begin
                                {req_buf_awstrb, req_buf_wdata}
                            <=  {strb,           wdata};
                        end
                    end
                end else begin
                    lookup_miss_way_replace_en <= lookup_miss_way_replace_en_w;
                    if (lookup_miss_need_send) begin
                        state <= state_reqw;
                    end else begin
                        state <= state_reqr;
                    end
                end
            end
            state_reqw: begin
                if (wr_rdy) begin
                    state <= state_send;
                end
            end
            state_send: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end else begin
                    state <= state_reqr;
                end
            end
            state_reqr: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end
            end
            state_recv: begin
                if (ret_valid) begin
                    if (recv_fin) begin
                        state <= state_idle;                        
                    end else begin
                        recv_buf[recv_cnt] <= ret_data;                        
                        recv_cnt <= recv_cnt + 1;
                    end
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
    

    // Write Buffer State Machine
    localparam  wr_buf_state_idle = 0;
    localparam  wr_buf_state_write = 1;
    reg         wr_buf_state;
    // wire wr_buf_state_is_idle = wr_buf_state == wr_buf_state_idle;
    wire wr_buf_state_is_write = wr_buf_state == wr_buf_state_write;
    wire wr_buf_accept_req = state_is_lookup && lookup_hit && req_buf_op;
    /// wr_buf_idle
    wire    [31:0]  wr_buf_wdata_mixed;
    wstrb_mixer u_wr_buf_mixer(
        .en         ( 1'b1              ),
        .x          ( req_buf_wdata     ),
        .y          ( lookup_hit_data   ),
        .wstrb      ( req_buf_awstrb    ),
        .f          ( wr_buf_wdata_mixed)
    );
    always @(posedge clock) begin
        if (reset) begin
            wr_buf_state <= wr_buf_state_idle;
            wr_buf_way <= 0;
            wr_buf_tag <= 0;
            wr_buf_idx <= 0;
            wr_buf_bank <= 0;
            wr_buf_wdata <= 0;
        end else case (wr_buf_state)
            wr_buf_state_idle: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way    , wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {lookup_way_hit, req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end                
            end 
            wr_buf_state_write: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way    , wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {lookup_way_hit, req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end else begin
                    wr_buf_state <= wr_buf_state_idle;
                end
            end
            default: begin
                wr_buf_state <= wr_buf_state_idle;
            end
        endcase
    end

    // i/o
    assign ready = !cache_sram_rw_collision && (
        (state_is_idle) ||
        (state_is_lookup && lookup_hit)
    );
    assign rvalid = !req_buf_op && (
        (state_is_lookup && lookup_hit) ||
        (state_is_recv && ret_valid && recv_cnt == req_buf_bank)
    );
    assign rdata = 
        ({req_buf_tag, req_buf_idx, req_buf_bank} == {wr_buf_tag, wr_buf_idx, wr_buf_bank}) ?
            wr_buf_wdata : (
                ({32{state_is_lookup}} & lookup_hit_data) |
                ({32{state_is_recv}} & ret_data)
            );
    assign rhit = state_is_lookup && !req_buf_op && lookup_hit;
    assign whit = state_is_lookup &&  req_buf_op && lookup_hit;
    assign cacop_ready = 1'b0;

    assign rd_req = state_is_send || state_is_reqr;
    assign rd_type = 3'b100;
    assign rd_addr = {req_buf_tag, req_buf_idx, 4'b0};
    assign wr_req = state_is_send;
    assign wr_type = 3'b100;
    assign wr_addr = {send_tag, req_buf_idx, 4'b0};
    assign wr_wstrb = 4'hf;
    // always @(*) begin
    //     wr_data = 128'b0;
    //     for (k = 0; k < DCACHE_WAY; k = k + 1) begin
    //         for (t = 0; t < 4; t = t + 1) begin
    //             wr_data[t*32 +: 32] = wr_data[t*32 +: 32] | 
    //                 ({32{lookup_miss_way_replace_en[k]}} & data_douta[k][t]);
    //         end
    //     end
    // end
    generate
        for (j = 0; j < 4; j = j + 1) begin
            assign wr_data[j*32 +: 32] = 
                ({32{lookup_miss_way_replace_en[0]}} & data_douta[0][j]) |
                ({32{lookup_miss_way_replace_en[1]}} & data_douta[1][j]);                        
        end
    endgenerate



    // cache sram

    `ifdef TEST

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 21            )
                // v [20], tag [19:0]
            ) u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                sram_sim #(
                    .ADDR_WIDTH     ( 8             ),
                    .DATA_WIDTH     ( 32            )
                ) u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate

    `else
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            dcache_tagv_sram u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                dcache_data_sram u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate


    `endif

    // cache control
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = 1'b1;
            assign tagv_wea[i] = 
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign tagv_addra[i] = 
                (state_is_idle)     ?   req_idx :
                (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                        req_buf_idx; 
            assign tagv_dina[i] =
                (state_is_recv)     ?   {1'b1, req_buf_tag} : 21'b0;
        end
    endgenerate
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                assign data_ena[i][j] = 1'b1;
                assign data_wea[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j) ||
                    (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
                assign data_addra[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j)  ?   wr_buf_idx :
                    (state_is_idle)     ?   req_idx :
                    (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                            req_buf_idx;
                assign data_dina[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j)  ?   wr_buf_wdata :
                    (state_is_recv)     ?   recv_mixed[j] :
                                            32'b0;
            end
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign dirt_wea[i] = 
                (wr_buf_state_is_write && wr_buf_way[i]) ||
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign dirt_addra[i] = 
                (wr_buf_state_is_write && wr_buf_way[i]) ? wr_buf_idx : req_buf_idx;
            assign dirt_addrb[i] = req_buf_idx;
            assign dirt_dina[i] = 
                (wr_buf_state_is_write)         ?   1'b1 :
                (state_is_recv && req_buf_op)   ?   1'b1 : 
                                                    1'b0;
        end
    endgenerate
endmodule

`define DCACHE_LRU

module dcache_v4(
    input               clock,
    input               reset,

    // cpu load / store
    /// common control (c) channel
    input               valid,
    output              ready,
    input               op,         // 0: read, 1: write
    input       [31:0]  addr,
    input       [ 3:0]  strb,
    input               uncached,
    /// read data (r) channel
    output              rvalid,
    output      [31:0]  rdata,
    output              rhit,
    /// write data (w) channel
    input       [31:0]  wdata,
    output              whit,
    /* verilator lint_off UNUSED */
    input               cacop_valid,
    output              cacop_ready,
    input       [ 1:0]  cacop_code, // code[4:3]
    input       [31:0]  cacop_addr,
    /* verilator lint_on UNUSED */

    // axi bridge
    output              rd_req,
    output      [ 2:0]  rd_type,
    output      [31:0]  rd_addr,
    input               rd_rdy,
    input               ret_valid,
    input               ret_last,
    input       [31:0]  ret_data,
    output              wr_req,
    output      [ 2:0]  wr_type,
    output      [31:0]  wr_addr,
    output      [ 3:0]  wr_wstrb,
    output reg [127:0]  wr_data,
    input               wr_rdy
    );

    parameter DCACHE_WAY = 4;

    genvar i; // way
    genvar j;
    integer k; // way
    integer t; // bank

    // cache ports

    wire            tagv_ena    [0:DCACHE_WAY-1];
    wire            tagv_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  tagv_addra  [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_dina   [0:DCACHE_WAY-1];
    wire    [20:0]  tagv_douta  [0:DCACHE_WAY-1];

    wire            data_ena    [0:DCACHE_WAY-1][ 0:3];
    wire            data_wea    [0:DCACHE_WAY-1][ 0:3];
    wire    [ 7:0]  data_addra  [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_dina   [0:DCACHE_WAY-1][ 0:3];
    wire    [31:0]  data_douta  [0:DCACHE_WAY-1][ 0:3];

    reg             dirt        [0:DCACHE_WAY-1][0:255];
    wire            dirt_wea    [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addra  [0:DCACHE_WAY-1];
    wire    [ 7:0]  dirt_addrb  [0:DCACHE_WAY-1];
    wire            dirt_dina   [0:DCACHE_WAY-1];
    wire            dirt_doutb  [0:DCACHE_WAY-1];

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            always @(posedge clock) begin
                if (dirt_wea[i]) begin
                    dirt[i][dirt_addra[i]] <= dirt_dina[i];
                end
            end
            assign dirt_doutb[i] = dirt[i][dirt_addrb[i]];
        end
    endgenerate

    // request
    /* verilator lint_off UNUSED */
    wire    [19:0]  req_tag;
    /* verilator lint_on UNUSED */
    wire    [ 7:0]  req_idx; 
    wire    [ 1:0]  req_bank;
    wire    [ 1:0]  req_off; 
    assign {req_tag, req_idx, req_bank, req_off} = addr;
    wire req_is_r_uc = !op && uncached;
    wire req_is_w_uc =  op && uncached;
    wire    [ 2:0]  req_size;
    strb2size u_strb2size(
        .strb   ( strb          ),
        .off    ( req_off       ),
        .size   ( req_size      )
    );


    // buffers
    /// req_buf
    reg             req_buf_op;
    reg     [31:0]  req_buf_addr;
    reg     [ 3:0]  req_buf_awstrb;
    reg     [31:0]  req_buf_wdata;
    wire    [19:0]  req_buf_tag;
    wire    [ 7:0]  req_buf_idx;
    wire    [ 1:0]  req_buf_bank;
    /* verilator lint_off UNUSED */
    wire    [ 1:0]  req_buf_off;
    /* verilator lint_on UNUSED */
    assign {req_buf_tag, req_buf_idx, req_buf_bank, req_buf_off} = req_buf_addr;

    /// wr_buf
    reg [DCACHE_WAY-1:0]    wr_buf_way;
    reg     [19:0]          wr_buf_tag;
    reg     [ 7:0]          wr_buf_idx;
    reg     [ 1:0]          wr_buf_bank;
    reg     [31:0]          wr_buf_wdata;

    /// hit_buf

    /// recv_buf
    reg     [31:0]  recv_buf        [ 0:2];
    reg     [ 1:0]  recv_cnt;


    // Main State Machine
    localparam      state_idle = 0;
    localparam      state_lookup = 1;
    localparam      state_reqw = 2;
    localparam      state_send = 3;
    localparam      state_reqr = 4;
    localparam      state_recv = 5;
    localparam      state_uncached = 6;
    reg     [ 2:0]  state;
    wire state_is_idle = state == state_idle;
    wire state_is_lookup = state == state_lookup;
    // wire state_is_reqw = state == state_reqw;
    wire state_is_send = state == state_send;
    wire state_is_reqr = state == state_reqr;
    wire state_is_recv = state == state_recv;
    wire state_is_uncached = state == state_uncached;

    wire cache_sram_rw_collision;
    assign cache_sram_rw_collision = 
        (valid && !uncached && wr_buf_state_is_write && wr_buf_bank == req_bank);

    /// idle
    /// lookup
    wire [DCACHE_WAY-1:0]   lookup_way_v;
    wire    [19:0]          lookup_way_tag      [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_d;
    wire    [31:0]          lookup_way_data     [0:DCACHE_WAY-1];
    wire [DCACHE_WAY-1:0]   lookup_way_hit;
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign {lookup_way_v[i], lookup_way_tag[i], lookup_way_data[i]}
                =  {tagv_douta[i]                     , data_douta[i][req_buf_bank]};
            assign lookup_way_d[i] = (wr_buf_way[i] && wr_buf_idx == req_buf_idx) ? 1'b1 : dirt_doutb[i];
            assign lookup_way_hit[i] = lookup_way_v[i] && (lookup_way_tag[i] == req_buf_tag);
            assign lookup_way_data[i] = data_douta[i][req_buf_bank];
        end
    endgenerate
    wire lookup_hit = |lookup_way_hit;
    // assume 2 ways
    reg      [31:0]  lookup_hit_data;    // combinational logic
    always @(*) begin
        lookup_hit_data = 0;
        for (k = 0; k < DCACHE_WAY; k = k + 1) begin
            lookup_hit_data = lookup_hit_data |
                ({32{lookup_way_hit[k]}} & lookup_way_data[k]);
        end        
    end
    wire [DCACHE_WAY-1:0]   lookup_miss_way_replace_en_w;
    reg  [DCACHE_WAY-1:0]   lookup_miss_way_replace_en;
    wire                    lookup_miss_need_send;
    `ifdef DCACHE_LRU
    generate
        if (DCACHE_WAY == 2) begin
            reg             lru     [0:255];
            replace_lru_2 u_replace(
                .clock          ( clock         ),
                .reset          ( reset         ),
                .en             ( 1'b1          ),
                .way_v          ( lookup_way_v  ),
                .way_d          ( lookup_way_d  ),
                .lru            ( lru[req_buf_idx]),
                .way_replace_en ( lookup_miss_way_replace_en_w ),
                .need_send      ( lookup_miss_need_send )
            );
            wire            lookup_hit_way;
            wire            lookup_miss_replace_way;
            assign lookup_hit_way = lookup_way_hit[1];
            assign lookup_miss_replace_way = lookup_miss_way_replace_en[1];
            always @(posedge clock) begin
                case (state) 
                state_lookup: begin
                    if (lookup_hit) begin
                        lru[req_buf_idx] <= ~lookup_hit_way;
                    end
                end
                state_recv: begin
                    if (recv_fin) begin
                        lru[req_buf_idx] <= ~lookup_miss_replace_way;
                    end
                end
                endcase
            end
        end else if (DCACHE_WAY == 4) begin
            reg             lru_o0  [0:255];
            reg     [ 1:0]  lru_o1  [0:255];
            wire    [ 1:0]  lookup_hit_way;
            wire    [ 1:0]  lookup_miss_replace_way;
            encoder_4_2 u_lookup_way(
                .in             ( lookup_way_hit),
                .out            ( lookup_hit_way)
            );
            encoder_4_2 u_replace_way(
                .in             ( lookup_miss_way_replace_en),
                .out            ( lookup_miss_replace_way)
            );
            replace_lru_4 u_replace(
                .clock          ( clock         ),
                .reset          ( reset         ),
                .en             ( 1'b1          ),
                .way_v          ( lookup_way_v  ),
                .way_d          ( lookup_way_d  ),
                .lru_o0         ( lru_o0[req_buf_idx]),
                .lru_o1         ( lru_o1[req_buf_idx]),
                .way_replace_en ( lookup_miss_way_replace_en_w ),
                .need_send      ( lookup_miss_need_send )
            );
            always @(posedge clock) begin
                case (state) 
                state_lookup: begin
                    if (lookup_hit) begin
                        lru_o0[req_buf_idx] <= ~lookup_hit_way[1];
                        lru_o1[req_buf_idx][lookup_hit_way[1]] <= ~lookup_hit_way[0];
                    end
                end
                state_recv: begin
                    if (recv_fin) begin
                        lru_o0[req_buf_idx] <= ~lookup_miss_replace_way[1];
                        lru_o1[req_buf_idx][lookup_miss_replace_way[1]] <= ~lookup_miss_replace_way[0];
                    end                    
                end
                endcase
            end            
        end
    endgenerate
    `else
    generate
        if (DCACHE_WAY == 2) begin
            replace_rand_2 u_replace(
                .clock          ( clock         ),
                .reset          ( reset         ),
                .en             ( 1'b1          ),
                .way_v          ( lookup_way_v  ),
                .way_d          ( lookup_way_d  ),
                .way_replace_en ( lookup_miss_way_replace_en_w ),
                .need_send      ( lookup_miss_need_send )
            );
        end else if (DCACHE_WAY == 4) begin
            replace_rand_4 u_replace(
                .clock          ( clock         ),
                .reset          ( reset         ),
                .en             ( 1'b1          ),
                .way_v          ( lookup_way_v  ),
                .way_d          ( lookup_way_d  ),
                .way_replace_en ( lookup_miss_way_replace_en_w ),
                .need_send      ( lookup_miss_need_send )
            );
        end
    endgenerate
    `endif
    /// send
    reg     [19:0]  send_tag; // combinational logic
    always @(*) begin
        send_tag = 0;
        for (k = 0; k < DCACHE_WAY; k = k + 1) begin
            send_tag = send_tag | 
                ({20{lookup_miss_way_replace_en[k]}} & lookup_way_tag[k]);
        end
    end
    /// recv
    wire recv_fin = ret_valid && (ret_last || recv_cnt == 2'd3);
    wire    [31:0]  recv_res    [ 0:3];
    generate
        for (j = 0; j < 3; j = j + 1) begin
            assign recv_res[j] = (recv_cnt == j) ? ret_data : recv_buf[j];
        end
        assign recv_res[3] = ret_data;
    endgenerate
    wire    [31:0]  recv_mixed  [ 0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin
            wstrb_mixer u_recv_mixer(
                .en     ( req_buf_op && req_buf_bank == j ),
                .x      ( req_buf_wdata     ),
                .y      ( recv_res[j]       ),
                .wstrb  ( req_buf_awstrb    ),
                .f      ( recv_mixed[j]     )
            );
        end
    endgenerate
    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            recv_buf[0] <= 0;
            recv_buf[1] <= 0;
            recv_buf[2] <= 0;
            req_buf_op <= 0;
            req_buf_addr <= 0;
            req_buf_awstrb <= 0;
            req_buf_wdata <= 0;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    if (uncached) begin
                        if (op && wr_rdy) begin
                            state <= state_idle;                            
                        end else if (!op && rd_rdy) begin
                            state <= state_uncached;                            
                        end
                    end else if (!cache_sram_rw_collision) begin
                        state <= state_lookup;
                            {req_buf_op, req_buf_addr}
                        <=  {op,         addr};
                        if (op) begin
                                {req_buf_awstrb, req_buf_wdata}
                            <=  {strb,           wdata};
                        end
                    end
                end
            end 
            state_lookup: begin
                if (lookup_hit) begin
                    if (!valid || cache_sram_rw_collision || (valid && uncached)) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;
                            {req_buf_op, req_buf_addr}
                        <=  {op,         addr};
                        if (op) begin
                                {req_buf_awstrb, req_buf_wdata}
                            <=  {strb,           wdata};
                        end
                    end
                end else begin
                    lookup_miss_way_replace_en <= lookup_miss_way_replace_en_w;
                    if (lookup_miss_need_send) begin
                        state <= state_reqw;
                    end else begin
                        state <= state_reqr;
                    end
                end
            end
            state_reqw: begin
                if (wr_rdy) begin
                    state <= state_send;
                end
            end
            state_send: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end else begin
                    state <= state_reqr;
                end
            end
            state_reqr: begin
                if (rd_rdy) begin
                    state <= state_recv;
                    recv_cnt <= 0;
                end
            end
            state_recv: begin
                if (ret_valid) begin
                    if (recv_fin) begin
                        state <= state_idle;                        
                    end else begin
                        recv_buf[recv_cnt] <= ret_data;                        
                        recv_cnt <= recv_cnt + 1;
                    end
                end
            end
            state_uncached: begin
                if (ret_valid) begin
                    state <= state_idle;
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
    

    // Write Buffer State Machine
    localparam  wr_buf_state_idle = 0;
    localparam  wr_buf_state_write = 1;
    reg         wr_buf_state;
    // wire wr_buf_state_is_idle = wr_buf_state == wr_buf_state_idle;
    wire wr_buf_state_is_write = wr_buf_state == wr_buf_state_write;
    wire wr_buf_accept_req = state_is_lookup && lookup_hit && req_buf_op;
    /// wr_buf_idle
    wire    [31:0]  wr_buf_wdata_mixed;
    wire    [31:0]  wr_buf_wdata_fwd = 
        (wr_buf_state_is_write && 
            ({req_buf_tag, req_buf_idx, req_buf_bank} == {wr_buf_tag, wr_buf_idx, wr_buf_bank})) ?
                wr_buf_wdata : lookup_hit_data;
    wstrb_mixer u_wr_buf_mixer(
        .en         ( 1'b1              ),
        .x          ( req_buf_wdata     ),
        .y          ( wr_buf_wdata_fwd  ),
        .wstrb      ( req_buf_awstrb    ),
        .f          ( wr_buf_wdata_mixed)
    );
    always @(posedge clock) begin
        if (reset) begin
            wr_buf_state <= wr_buf_state_idle;
            wr_buf_way <= 0;
            wr_buf_tag <= 0;
            wr_buf_idx <= 0;
            wr_buf_bank <= 0;
            wr_buf_wdata <= 0;
        end else case (wr_buf_state)
            wr_buf_state_idle: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way    , wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {lookup_way_hit, req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end                
            end 
            wr_buf_state_write: begin
                if (wr_buf_accept_req) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_way    , wr_buf_tag , wr_buf_idx,  wr_buf_bank,  wr_buf_wdata}
                    <=  {lookup_way_hit, req_buf_tag, req_buf_idx, req_buf_bank, wr_buf_wdata_mixed};
                end else begin
                    wr_buf_state <= wr_buf_state_idle;
                end
            end
            default: begin
                wr_buf_state <= wr_buf_state_idle;
            end
        endcase
    end

    // i/o
    assign ready = !cache_sram_rw_collision && (
        (state_is_idle && (
            (!uncached) ||
            ( uncached && ((!op && rd_rdy) || (op && wr_rdy)))
         )
        ) ||
        (state_is_lookup && lookup_hit && !uncached)
    );
    assign rvalid = (!req_buf_op && (
        (state_is_lookup && lookup_hit) ||
        (state_is_recv && ret_valid && recv_cnt == req_buf_bank)
    )) || (state_is_uncached && ret_valid);
    assign rdata = 
        (state_is_uncached) ? ret_data :
        ({req_buf_tag, req_buf_idx, req_buf_bank} == {wr_buf_tag, wr_buf_idx, wr_buf_bank}) ?
            wr_buf_wdata : (
                ({32{state_is_lookup}} & lookup_hit_data) |
                ({32{state_is_recv}} & ret_data)
            );
    assign rhit = state_is_lookup && !req_buf_op && lookup_hit;
    assign whit = state_is_lookup &&  req_buf_op && lookup_hit;
    assign cacop_ready = 1'b0;

    assign rd_req = (state_is_send || state_is_reqr) || (state_is_idle && valid && req_is_r_uc);
    assign rd_type = (state_is_idle) ? req_size : 3'b100;
    assign rd_addr = (state_is_idle) ? addr : {req_buf_tag, req_buf_idx, 4'b0};
    assign wr_req = (state_is_send) || (state_is_idle && valid && req_is_w_uc);
    assign wr_type = (state_is_idle) ? req_size : 3'b100;
    assign wr_addr = (state_is_idle) ? addr : {send_tag, req_buf_idx, 4'b0};
    assign wr_wstrb = (state_is_idle) ? strb : 4'hf;
    always @(*) begin
        wr_data = 128'b0;
        for (k = 0; k < DCACHE_WAY; k = k + 1) begin
            for (t = 0; t < 4; t = t + 1) begin
                wr_data[t*32 +: 32] = wr_data[t*32 +: 32] | 
                    ({32{lookup_miss_way_replace_en[k]}} & data_douta[k][t]);
            end
        end
        if (state_is_idle && valid && uncached) begin
            wr_data[31:0] = wdata;
        end
    end

    // cache sram

    `ifdef TEST

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            sram_sim #(
                .ADDR_WIDTH     ( 8             ),
                .DATA_WIDTH     ( 21            )
                // v [20], tag [19:0]
            ) u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                sram_sim #(
                    .ADDR_WIDTH     ( 8             ),
                    .DATA_WIDTH     ( 32            )
                ) u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate

    `else
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            dcache_tagv_sram u_tagv_sram(
                .clka           ( clock         ),
                .ena            ( tagv_ena[i]   ),
                .wea            ( tagv_wea[i]   ),
                .addra          ( tagv_addra[i] ),
                .dina           ( tagv_dina[i]  ),
                .douta          ( tagv_douta[i] )
            );
            
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                dcache_data_sram u_data_sram(
                    .clka           ( clock             ),
                    .ena            ( data_ena[i][j]    ),
                    .wea            ( data_wea[i][j]    ),
                    .addra          ( data_addra[i][j]  ),
                    .dina           ( data_dina[i][j]   ),
                    .douta          ( data_douta[i][j]  )
                );
            end
        end
    endgenerate


    `endif

    // cache control
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign tagv_ena[i] = 1'b1;
            assign tagv_wea[i] = 
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign tagv_addra[i] = 
                (state_is_idle)     ?   req_idx :
                (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                        req_buf_idx; 
            assign tagv_dina[i] =
                (state_is_recv)     ?   {1'b1, req_buf_tag} : 21'b0;
        end
    endgenerate
    
    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                assign data_ena[i][j] = 1'b1;
                assign data_wea[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j) ||
                    (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
                assign data_addra[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j)  ?   wr_buf_idx :
                    (state_is_idle)     ?   req_idx :
                    (state_is_lookup)   ?   (lookup_hit ? req_idx : req_buf_idx) :
                                            req_buf_idx;
                assign data_dina[i][j] = 
                    (wr_buf_state_is_write && wr_buf_way[i] && wr_buf_bank == j)  ?   wr_buf_wdata :
                    (state_is_recv)     ?   recv_mixed[j] :
                                            32'b0;
            end
        end
    endgenerate

    generate
        for (i = 0; i < DCACHE_WAY; i = i + 1) begin
            assign dirt_wea[i] = 
                (wr_buf_state_is_write && wr_buf_way[i]) ||
                (state_is_recv && recv_fin && lookup_miss_way_replace_en[i]);
            assign dirt_addra[i] = 
                (wr_buf_state_is_write && wr_buf_way[i]) ? wr_buf_idx : req_buf_idx;
            assign dirt_addrb[i] = req_buf_idx;
            assign dirt_dina[i] = 
                (wr_buf_state_is_write)         ?   1'b1 :
                (state_is_recv && req_buf_op)   ?   1'b1 : 
                                                    1'b0;
        end
    endgenerate
endmodule
