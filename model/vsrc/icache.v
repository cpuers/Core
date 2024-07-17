/* verilator lint_off DECLFILENAME */

module icache_dummy(
    input           clock,
    input           reset,

    // cpu ifetch
    /// read address (ar) channel
    input           arvalid,      // in cpu, valid no dep on ready;
    output          arready,    // in cache, ready can dep on valid
    input   [31:0]  araddr,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    // cpu cacop
    /* verilator lint_off UNUSED */
    input           cacop_en,
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
    input   [31:0]  ret_data
);
    localparam      state_idle = 0;
    localparam      state_request = 1;  // wait axi rd_ready
    localparam      state_receive = 2;  // wait axi ret_last
    reg     [ 2:0]  state;
    wire state_is_idle = (state == state_idle);
    wire state_is_request = (state == state_request);

    reg     [31:0]  request_buffer;

    reg     [31:0]  buffer  [ 0:2];
    reg     [ 1:0]  buffer_cnt;

    wire            buffer_receive_end;
    assign buffer_receive_end = 
        (state == state_receive) && (ret_last | (buffer_cnt == 2'd3));

    assign arready = (state == state_idle) & arvalid;
    assign rvalid = buffer_receive_end;
    assign rdata = {buffer[0], buffer[1], buffer[2], ret_data};

    assign rd_req = 
        (state_is_idle && arvalid) || 
        (state_is_request);
    assign rd_type = 3'b100;
    assign rd_addr =
        ({32{state_is_idle}} & araddr) |
        ({32{state_is_request}} & request_buffer);

    /* State Machine */
    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
            request_buffer <= 0;
            buffer_cnt <= 0;
        end else case (state)
            state_idle: begin
                if (arvalid) begin
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


module icache_v1 (
    input           clock,
    input           reset,
    // cpu
    input           valid,
    output          addr_ok,
    input   [31:0]  addr,
    output          data_ok,
    output  [127:0] rdata,
    // axi_bridge
    output          rd_req,
    output  [ 2:0]  rd_type,
    output  [31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input   [31:0]  ret_data
);
    wire    [19:0]  tag;
    wire    [ 7:0]  idx;

    assign tag = addr[31:12];
    assign idx = addr[11:4];

    genvar  i;

    // ************
    // * Datapath *
    // ************

    wire            tagv_ena;
    wire            tagv_wea;
    wire    [ 7:0]  tagv_addra;
    wire    [20:0]  tagv_dina;
    wire    [20:0]  tagv_douta;

    wire            data_ena;
    wire            data_wea;
    wire    [ 7:0]  data_addra;
    wire    [127:0] data_dina;
    wire    [127:0] data_douta;

    assign tagv_ena = (state_is_idle && valid);
    assign tagv_wea = (state_is_wb);
    assign tagv_addra = 
        (state_is_wb) ? request_buffer_idx : idx;
    assign tagv_dina = {request_buffer_tag, 1'b1};

    assign data_ena = state_is_lookup1 && hit;
    assign data_wea = (state_is_wb);
    assign data_addra = request_buffer_idx;
    assign data_dina = refill_res;

    // cpu

    assign addr_ok = state_is_idle;
    assign data_ok = state_is_lookup2 | state_is_wb;
    assign rdata =
        ({128{state_is_lookup2}} & data_douta) |
        ({128{state_is_wb}} & refill_res);

    // axi

    assign rd_req =
        (state == state_request && rd_rdy);
    assign rd_addr =
        {request_buffer_tag, request_buffer_idx, 4'b0};

    /* cache */
    `ifdef TEST
    sram_sim #(
        .ADDR_WIDTH     (8          ),
        .DATA_WIDTH     (21         )
        // [20:1] tag   [0:0] v
    ) u_tagv_sram (
        .clka           (clock      ),
        .ena            (tagv_ena   ),
        .wea            (tagv_wea   ),
        .addra          (tagv_addra ),
        .dina           (tagv_dina  ),
        .douta          (tagv_douta )
    );

    sram_sim #(
        .ADDR_WIDTH     (8          ),
        .DATA_WIDTH     (128        )
    ) u_data_sram (
        .clka           (clock      ),
        .ena            (data_ena   ),
        .wea            (data_wea   ),
        .addra          (data_addra ),
        .dina           (data_dina  ),
        .douta          (data_douta ),
    );

    `else

    `endif

    /* request buffer */
    reg     [19:0]  request_buffer_tag;
    reg     [ 7:0]  request_buffer_idx;

    /* hit */
    wire            hit;
    assign hit = tagv_douta[0] & (request_buffer_tag == tagv_douta[20:1]);

    /* refill buffer */
    reg     [31:0]  refill_buffer   [0:3];
    reg     [ 1:0]  refill_count;
    wire            refill_done;
    assign refill_done = refill_count == 2'd3;
    wire    [127:0] refill_res;
    assign refill_res =
        {refill_buffer[0], refill_buffer[1], refill_buffer[2], refill_buffer[3]};



    // *****************
    // * State Machine *
    // *****************

    localparam state_idle    = 4'd0;
    localparam state_lookup1 = 4'd1;
    localparam state_lookup2 = 4'd2;
    localparam state_request = 4'd3;
    localparam state_receive = 4'd4;
    localparam state_wb      = 4'd5;

    reg     [ 3:0]  state;
    wire            state_is_idle;
    wire            state_is_lookup1;
    wire            state_is_lookup2;
    wire            state_is_request;
    wire            state_is_receive;
    wire            state_is_wb;
    assign state_is_idle = state == state_idle;
    assign state_is_lookup1 = state == state_lookup1;
    assign state_is_lookup2 = state == state_lookup2;
    assign state_is_request = state == state_request;
    assign state_is_receive = state == state_receive;
    assign state_is_wb = state == state_wb;

    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;

            request_buffer_idx <= 8'd0;
            request_buffer_tag <= 20'd0;
            refill_buffer[0] <= 32'd0;
            refill_buffer[1] <= 32'd0;
            refill_buffer[2] <= 32'd0;
            refill_buffer[3] <= 32'd0;
            refill_count <= 2'd0;
        end else case (state)
            state_idle: begin
                if (valid) begin
                    state <= state_lookup1;

                    request_buffer_idx <= idx;
                    request_buffer_tag <= tag;
                end                
            end 
            state_lookup1: begin
                if (hit) begin
                    state <= state_lookup2;                    
                end else begin
                    state <= state_request;
                end
            end
            state_lookup2: begin
                state <= state_idle;                
            end
            state_request: begin
                if (rd_rdy) begin
                    state <= state_receive;
                    refill_count <= 2'd0;
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    refill_buffer[refill_count] <= ret_data;
                    if (refill_done) begin
                        state <= state_idle;
                    end else begin
                        refill_count <= refill_count + 1;
                    end
                end
            end
            state_wb: begin
                state <= state_idle;                
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule

module icache_v2(
    input           clock,
    input           reset,

    // cpu ifetch
    /// read address (ar) channel
    input           arvalid,      // in cpu, valid no dep on ready;
    output          arready,    // in cache, ready can dep on valid
    input   [31:0]  araddr,
    /* verilator lint_off UNUSED */
    input           uncached,
    /* verilator lint_on UNUSED */
    /// read data (r) channel
    output          rvalid,
    output [127:0]  rdata,
    // cpu cacop
    /* verilator lint_off UNUSED */
    input           cacop_en,
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
    input   [31:0]  ret_data
);
    

endmodule
