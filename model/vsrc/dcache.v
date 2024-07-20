/* verilator lint_off DECLFILENAME */

/* verilator lint_off UNUSED */
module dcache_dummy (
    input           clock,
    input           reset,

    // cpu load / store
    /// common control (c) channel
    input           valid,
    output          ready,
    input           op,         // 0: read, 1: write
    input   [31:0]  addr,
    input           uncached,
    /// read data (r) channel
    output          rvalid,
    output  [31:0]  rdata,
    /// write address (aw) channel
    input   [ 3:0]  awstrb,
    /// write data (w) channel
    input   [31:0]  wdata,
    input           cacop_en,
    input   [ 1:0]  cacop_code, // code[4:3]
    input   [31:0]  cacop_addr,

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
    assign rvalid = ret_last;
    assign rdata = ret_data;
    wire request_is_read = (state_is_request && !op);
    wire request_is_write = (state_is_request && op);
    assign rd_req = request_is_read;
    assign rd_type = 3'b010;
    assign rd_addr = {{30{request_is_read}}, 2'b0} & req_addr;
    assign wr_req = request_is_write;
    assign wr_type = 3'b010;
    assign wr_addr = {{30{request_is_write}}, 2'b0} & req_addr;
    assign wr_wstrb = req_awstrb;
    assign wr_data = {96'b0, req_wdata};

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
                end
            end
            state_request: begin
                if (op) begin
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
                if (ret_last) begin
                    state <= state_idle;
                end
            end
            default: begin
                state <= state_idle;
            end
        endcase
    end
endmodule
/* verilator lint_on UNUSED */

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
    /// write address (aw) channel
    input   [ 3:0]  awstrb,
    /// write data (w) channel
    input   [31:0]  wdata,
    input           cacop_en,
    /* verilator lint_off UNUSED */
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
    assign receive_finish = state_is_receive && ret_last;
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
        (cacop_en || (op && wr_rdy) || (!op && rd_rdy));
    assign rvalid = receive_finish;
    assign rdata = ret_data;
    //  (state_is_idle && valid && !cacop_en && !op) ||
    //  (state_is_receive && receive_finish && valid && !cacop_en && !op);
    assign rd_req = 
        state_can_accept_request && valid && !cacop_en && !op;
    assign rd_type = 3'b010;
    assign rd_addr = {30'b1, 2'b0} & addr;
    //  (state_is_idle && valid && !cacop_en && op) ||
    //  (state_is_receive && receive_finish && valid && op);
    assign wr_req = 
        state_can_accept_request && valid && !cacop_en && op;
    assign wr_type = 3'b010;
    assign wr_addr = {30'b1, 2'b0} & addr;
    assign wr_wstrb = awstrb;
    assign wr_data = {96'b0, wdata};

    always @(posedge clock) begin
        if (reset) begin
            state <= state_reset;
        end else case (state)
            state_idle: 
            // begin
            //     if (valid) begin
            //         if (cacop_en) begin
            //             state <= state_idle;                        
            //         end else begin
            //             if (op) begin
            //                 if (wr_rdy) begin
            //                     state <= state_idle;
            //                 end                            
            //             end else begin
            //                 if (rd_rdy) begin
            //                     state <= state_receive;
            //                 end
            //             end                       
            //         end
            //     end
            // end
            begin
                if (valid) begin
                    if (!op && !cacop_en && rd_rdy) begin
                        state <= state_receive;
                    end
                end
            end
            state_receive: begin
                if (ret_valid) begin
                    if (valid) begin
                        if (cacop_en) begin
                            state <= state_idle;                        
                        end else begin
                            state <= state_idle;                        
                            if (op) begin
                                if (wr_rdy) begin
                                    state <= state_idle;
                                end
                            end else begin
                                if (rd_rdy) begin
                                    state <= state_receive;
                                end
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
