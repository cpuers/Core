/* verilator lint_off DECLFILENAME */

module dcache_dummy (
    input           clock,
    input           reset,

    // cpu load / store
    /// common control (c) channel
    input           valid,
    output          ready,
    input           op,         // 0: read, 1: write
    input   [31:0]  addr,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    output          rhit,
    /// write address (aw) channel
    input   [ 3:0]  awstrb,
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
    reg     [ 3:0]  req_awstrb;
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
    assign wr_wstrb = req_awstrb;
    assign wr_data = {96'b0, req_wdata};

    assign rhit = 1'b0;
    assign whit = 1'b0;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
            req_op <= 0;
            req_addr <= 0;
            req_awstrb <= 0;
            req_wdata <= 0;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    req_op <= op;
                    req_addr <= addr;
                    if (op) begin
                        req_awstrb <= awstrb;
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
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    output          rhit,
    /// write address (aw) channel
    input   [ 3:0]  awstrb,
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
    assign wr_wstrb = awstrb;
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
    input               uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output              rvalid,
    output      [31:0]  rdata,
    output              rhit,
    /// write address (aw) channel
    input       [ 3:0]  awstrb,
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
    genvar j; // bank
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
    assign lookup_line_d = dirt[req_buf_idx];
    wire lookup_ret = state_is_lookup && lookup_hit && !req_buf_op;
    assign lookup_need_replace = !lookup_hit && lookup_line_v && lookup_line_d;
    /// receive
    wire                recv_fin;
    assign recv_fin = ret_valid && (ret_last || recv_cnt == 2'd3);
    wire recv_ret = state_is_recv && recv_fin;
    wire    [31:0]      recv_res    [ 0:3];
    generate
        for (j = 0; j < 3; j = j + 1) begin
            assign recv_res[j] = recv_buf[j];
        end
        assign recv_res[3] = ret_data;
    endgenerate


    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end case (state)
            state_idle: begin
                if (valid) begin
                    if (cache_sram_rw_collision) begin
                        state <= state_idle;
                    end else begin
                        state <= state_lookup;

                            {req_buf_op, req_buf_tag, req_buf_idx, req_buf_bank}
                        <=  {op        , addr[31:12], addr[11:4] , addr[3:2]};
                        if (op) begin
                            req_buf_awstrb <= awstrb;
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
                            req_buf_awstrb <= awstrb;
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
    always @(posedge clock) begin
        if (reset) begin
            wr_buf_state <= wr_buf_state_idle;
        end else case (wr_buf_state)
            wr_buf_state_idle: begin
                if (lookup_hit && req_buf_op) begin
                    wr_buf_state <= wr_buf_state_write;
                        {wr_buf_idx,  wr_buf_bank,  wr_buf_awstrb,  wr_buf_wdata}
                    <=  {req_buf_idx, req_buf_bank, req_buf_awstrb, req_buf_wdata};
                end                
            end 
            wr_buf_state_write: begin
                wr_buf_state <= wr_buf_state_idle;
                dirt[wr_buf_idx] <= 1'b1;
            end
            default: begin
                wr_buf_state <= wr_buf_state_idle;
            end
        endcase
    end

    // i/o
    assign ready = 
        (state_is_idle) ||
        (state_is_lookup && !cache_sram_rw_collision);
    assign rvalid = (lookup_ret || recv_ret) && !req_buf_op;
    assign rdata = 
        ({32{lookup_ret}} & lookup_hit_data) |
        ({32{recv_ret}} & recv_res[req_buf_bank]);
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
    assign wr_addr = req_buf_line_addr;
    assign wr_wstrb = 4'hf;
    always @(*) begin
        for (t = 0; t < 4; t = t + 1) begin
            wr_data[t*32 +: 32] = data_douta[t];
        end
    end
    assign wr_data = {data_douta[3], data_douta[2], data_douta[1], data_douta[0]};

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
endmodule
