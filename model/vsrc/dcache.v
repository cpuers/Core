/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */

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
    reg         state;
    wire state_is_idle = state == state_idle;
    wire state_is_request = state == state_request;

    reg     [31:0]  req_addr;
    reg     [ 3:0]  req_awstrb;
    reg     [31:0]  req_wdata;

    assign ready = state_is_idle && (
        (!op & rd_rdy) |
        ( op)    
    );
    assign rvalid = ret_valid && ret_last;
    assign rdata = ret_data;
    
    assign rd_req = valid && !op;
    assign rd_type = 3'b010;
    assign rd_addr = {addr[31:2], 2'b0};
    assign wr_req = (state_is_idle && op) | state_is_request;
    assign wr_type = 3'b010;
    assign wr_addr = 
        ({32{state_is_idle}} & {addr[31:2], 2'b0}) |
        ({32{state_is_request}} & {req_addr[31:2], 2'b0});
    assign wr_wstrb = (state_is_idle) ? awstrb : req_awstrb;
    assign wr_data = {96'b0, (state_is_idle) ? wdata : req_wdata};

    always @(posedge clock) begin
        if (reset) begin
            state <= state_idle;
        end else case (state)
            state_idle: begin
                if (op) begin
                    state <= state_request;
                    req_addr <= addr;
                    req_awstrb <= awstrb;
                    req_wdata <= wdata;
                end
            end
            state_request: begin
                if (wr_rdy) begin
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
