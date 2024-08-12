`include "define.vh"

module EXM_stage(
    input                           clk,
    input                           reset,
    //for ID
    output                          es_ready,
    input                           ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD - 1:0] ds_to_es_bus,
    //for WB
    input                           ws_ready,
    output [                   1:0] es_to_ws_valid,
    output [`ES_TO_WS_BUS_WD - 1:0] es_to_ws_bus,
    output                          nblock,
    //for MEM
    output [`ES_TO_MS_BUS_WD - 1:0] es_to_ms_bus,
    input  [`MS_TO_ES_BUS_WD - 1:0] ms_to_es_bus,
    input excp_ale,
    //for div
    output [`ES_TO_DIV_BUS_MD -1:0] es_to_div_bus,
    input  [`DIV_TO_ES_BUS_MD -1:0] div_to_es_bus,
    //for mul
    output [`ES_TO_MUL_BUS_MD -1:0] es_to_mul_bus,
    input  [`MUL_TO_ES_BUS_MD -1:0] mul_to_es_bus,

    input  [ `FORWAED_BUS_WD - 1:0] forward_data1,
    input  [ `FORWAED_BUS_WD - 1:0] forward_data2,
    //output [ `FORWAED_BUS_WD - 1:0] exm_forward_bus,

    output [      `BR_BUS_WD - 1:0] br_bus,
    output                          flush_IF,
    output                          flush_ID,
    input                           flush_ES,

    output [     `CSR_BUS_WD - 1:0] csr_bus,
    input                           jump_excp_fail,
    input                           excp_jump,
    input  [                  31:0] excp_pc,
    output [                  13:0] csr_addr,
    input  [                  31:0] csr_rdata_t,

    input another_ok,
    output my_ok,
    output [`BPU_ES_BUS_WD-1:0]     bpu_es_bus

    `ifdef DIFFTEST_EN
    ,

    input  [`DS_ES_DEBUG_BUS_WD-1:0] ds_to_es_debug_bus,
    output [`ES_WS_DEBUG_BUS_WD-1:0] es_to_ws_debug_bus,
    input [63:0] csr_timer_64_diff,
    input [10:0] intrNo_diff 
    `endif 

);

//wire [`FORWAED_BUS_WD -1:0]  exm_forward_bus_w;
wire        cacop_valid;
wire        flush_icache;
wire        flush_dcache;
wire  [1:0] cacop_code;
wire        cacop_ok;
wire        in_excp;
wire        in_excp_t;
wire        is_etrn;
wire        is_etrn_t;
wire [5:0]  excp_Ecode;
wire [5:0]  excp_Ecode_t;
wire [8:0]  excp_subEcode;
wire [8:0]  excp_subEcode_t;
wire        use_badv_t;
wire        use_badv;
wire [31:0] bad_addr;
wire [31:0] bad_addr_t;
wire        use_csr_data;
wire        csr_wen;
//wire [13:0] csr_addr;
//wire [31:0] csr_rdata_t;
//wire [13:0] csr_addr;
//wire [31:0] csr_rdata_t;
wire [31:0] csr_rdata;
wire [31:0] csr_wdata_t;
wire [31:0] csr_wdata;
wire        use_mark;

wire [11:0] alu_op;
wire [ 3:0] bit_width;
wire [ 1:0] jump_type;
wire        may_jump;  // 1 
wire        use_rj_value;  // 1
wire        use_less;  // 1
wire        need_less;  // 1
wire        use_zero;  // 1
wire        need_zero;  // 1
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [31:0] imm;
wire [ 4:0] rf_raddr1;
wire [ 4:0] rf_raddr2;
wire [31:0] rj_value;
wire [31:0] rj_value_t;
wire [31:0] rkd_value;
wire [31:0] rkd_value_t;
wire [31:0] es_pc;
wire        is_jump;
wire        res_from_mem;
wire        use_mul;
wire        use_high;
wire        is_unsigned;
wire        use_div;
wire        use_mod;

wire        pre_fail;
wire        flush;

wire [31:0] src1;
wire [31:0] src2;
wire [31:0] alu_result; 
wire [31:0] mul_result;
wire [31:0] div_result;
wire [31:0] div_result0;

wire [31:0] mem_result;
wire [31:0] final_result;
wire        div_ok;
wire        mul_ok;

wire        need_jump;
wire [31:0] branch_target;
wire [31:0] jump_target;

wire        zero;
wire        less;

//reg  [ `FORWAED_BUS_WD-1:0] exm_forward_bus_r;
//wire [ `FORWAED_BUS_WD-1:0] exm_forward_bus_w;
//reg  [ `FORWAED_BUS_WD-1:0] exm_forward_bus_r;
//wire [ `FORWAED_BUS_WD-1:0] exm_forward_bus_w;

wire [                 1:0] es_to_ws_valid_w;
wire [`ES_TO_WS_BUS_WD-1:0] es_to_ws_bus_w;
reg  [`ES_TO_WS_BUS_WD+1:0] es_to_ws_bus_r;
wire                        dcache_ok;

wire [1:0] forw_rj;
wire [1:0] forw_rkd;
wire [1:0] forw_csr;

wire cal_valid;
reg  [31:0] temp_r;
reg [1:0] state;
wire wait_another;

assign {
    cacop_valid,
    flush_icache,
    flush_dcache,
    cacop_code,
    in_excp_t, //1   例外
    excp_Ecode_t, //6
    excp_subEcode_t, //9
    is_etrn_t, //1   中断
    use_badv_t,
    bad_addr_t, //1
    use_csr_data, //1
    csr_wen, //1
    csr_addr, //14
    use_mark,

    alu_op,  // 12  操作类型
    bit_width,  // 4  访存宽度 ls
    jump_type,
    may_jump,  // 1   跳转 分支处理 ---
    use_rj_value,  // 1  绝对跳转
    use_less,  // 1    跳转需要   0无意义
    need_less,  // 1   1 1 1跳   1 0 0跳
    use_zero,  // 1
    need_zero,  // 1
    src1_is_pc,  // 1   操作数1为pc
    src2_is_imm,  // 1  操作数2为立即数
    src2_is_4,  // 1    操作数2为pc+
    gr_we,  // 1    写寄存器
    mem_we,  // 1   写内存 store
    dest,  // 5   目的地址
    imm,  // 32  立即数
    rf_raddr1,  //5    操作数1寄存器rj地址
    rf_raddr2,  //5    操作数2寄存器rk\rd地址
    rj_value_t,  // 32   操作数1（绝对跳转的地址
    rkd_value_t,  // 32  操作数2
    es_pc,  // 32   这条指令pc
    is_jump,  //1
    res_from_mem,  //1  读内存 load
    use_mul,
    use_high,
    is_unsigned,
    use_div,
    use_mod
} = ds_to_es_bus;

//assign es_ready_go = 1'b1;
assign my_ok = (!jump_excp_fail & (dcache_ok || ~(mem_we || res_from_mem)) && (div_ok||~use_div) && (mul_ok||~use_mul)& (~cacop_valid || cacop_ok) ) || ~ds_to_es_valid ||(in_excp&~jump_excp_fail) || flush_ES;
assign nblock = my_ok;
assign es_to_ws_valid_w[0] = ds_to_es_valid;
//assign es_to_ws_valid_w[1] =  state==idle || (state==wait_an_state&&another_ok) || (state==wait_me_state&&my_ok&&another_ok);
assign es_to_ws_valid_w[1] = another_ok && my_ok;
assign es_to_ws_bus_w = {csr_wen, csr_addr, csr_wdata, gr_we&!in_excp, dest, final_result, es_pc};
//assign exm_forward_bus_w = {es_to_ws_valid_w[0],csr_wen, csr_addr, csr_wdata, gr_we&!in_excp, dest, final_result};

assign es_ready = ws_ready; 

localparam wait_me_state = 2'b01;
localparam wait_an_state = 2'b10;
localparam idle = 2'b00;

assign wait_another = ~|(state^wait_an_state);
assign cal_valid = ds_to_es_valid && !(wait_another);

always @(posedge clk) begin
    if(reset || flush_ES) begin
        state <= idle;
    end
    else if(state== idle) begin
        if(!my_ok) 
        begin
            state <= wait_me_state;
        end
        else // my_ok = 1 
        begin
            if(!another_ok) 
            begin
                state <= wait_an_state;
                temp_r <= final_result;
            end
            else  
            begin
                state <= idle;
            end
        end
    end
    else if(state==wait_an_state && another_ok)
    begin
         state <= idle;
    end
    else if(state==wait_me_state && my_ok) begin
        if(another_ok)
        begin
            state <= idle;
        end
        else
        begin
            state <= wait_an_state;
            temp_r <= final_result;
        end
    end

end

always @(posedge clk) 
begin
    if (reset|flush_ES) 
    begin
       es_to_ws_bus_r[`ES_TO_WS_BUS_WD+1:`ES_TO_WS_BUS_WD] <= 2'b0;
      //es_to_ws_bus_r[`ES_TO_WS_BUS_WD+1]<=1'b1;
    end 
    else if(!ws_ready)
    begin
      es_to_ws_bus_r[`ES_TO_WS_BUS_WD:0] <= es_to_ws_bus_r[`ES_TO_WS_BUS_WD:0];
      es_to_ws_bus_r[`ES_TO_WS_BUS_WD+1] <= es_to_ws_valid_w[1];
    end 
    else
    begin 
        es_to_ws_bus_r[`ES_TO_WS_BUS_WD-1:0] <= es_to_ws_bus_w;
        es_to_ws_bus_r[`ES_TO_WS_BUS_WD+1:`ES_TO_WS_BUS_WD] <= es_to_ws_valid_w;
    end

    // if(reset) begin
    //     exm_forward_bus_r <= 0;
    // end
    // if(!nblock && (forw_rj[0] || forw_rj[1] || forw_rkd[0] || forw_rkd[1])) begin
    //     exm_forward_bus_r <= exm_forward_bus_r;
    // end
    // else begin
    //     exm_forward_bus_r <= exm_forward_bus_w;
    //     //exm_forward_bus_r[`FORWAED_BUS_WD-2:0] <= es_to_ws_bus_w[`ES_TO_WS_BUS_WD-1:32];
    //     //exm_forward_bus_r[`FORWAED_BUS_WD-1] <= es_to_ws_valid_w[0];  //ds_to_es_valid
    // end

end

assign es_to_ws_valid  = es_to_ws_bus_r[`ES_TO_WS_BUS_WD+1:`ES_TO_WS_BUS_WD];
assign es_to_ws_bus    = es_to_ws_bus_r[`ES_TO_WS_BUS_WD-1:0];
//assign exm_forward_bus = exm_forward_bus_r; //es_to_ws_bus_r[`ES_TO_WS_BUS_WD:32]; //exm_forward_bus_r;
//assign exm_forward_bus = exm_forward_bus_r; //es_to_ws_bus_r[`ES_TO_WS_BUS_WD:32]; //exm_forward_bus_r;
//assign exm_forward_bus = exm_forward_bus_r; //es_to_ws_bus_r[`ES_TO_WS_BUS_WD:32]; //exm_forward_bus_r;
 `ifdef DIFFTEST_EN

  wire [`ES_WS_DEBUG_BUS_WD-1:0] es_to_ws_debug_bus_w;
  reg  [`ES_WS_DEBUG_BUS_WD-1:0] es_to_ws_debug_bus_r;

  wire [31:0] cmt_wdata;
  wire [31:0] cmt_csr_rdata;
  wire cmt_excp_valid;
  wire [5:0] cmt_estat_ecode;
  wire [31:0] cmt_st_vaddr;
  wire [31:0] cmt_st_paddr;
  wire [31:0] cmt_st_data ;
  wire [31:0] cmt_ld_vaddr;
  wire [31:0] cmt_ld_paddr;

  assign cmt_wdata = final_result;
  assign cmt_csr_rdata = csr_rdata; 
  assign cmt_excp_valid = in_excp;
  assign cmt_estat_ecode = excp_Ecode;
  assign cmt_st_vaddr = alu_result;
  assign cmt_st_paddr = alu_result;
  assign cmt_st_data = rkd_value;
  assign cmt_ld_vaddr = alu_result;
  assign cmt_ld_paddr = alu_result; 
  assign es_to_ws_debug_bus_w = {cmt_st_vaddr, cmt_st_paddr, cmt_st_data, cmt_ld_vaddr, cmt_st_paddr,
                                csr_timer_64_diff, intrNo_diff, cmt_excp_valid, cmt_estat_ecode, cmt_wdata,cmt_csr_rdata, 
                                ds_to_es_debug_bus};

  always @(posedge clk ) 
  begin
    if (reset) begin
        es_to_ws_debug_bus_r <= `ES_WS_DEBUG_BUS_WD'h0; 
    end
    else
    begin
        es_to_ws_debug_bus_r <= es_to_ws_debug_bus_w;
    end  
  end
  assign es_to_ws_debug_bus = es_to_ws_debug_bus_r;
  `endif 

//csr forward
assign forw_csr[0] = forward_data1[`FORWAED_BUS_WD-1] && forward_data1[84] && use_csr_data && ~|(forward_data1[83:70]^csr_addr);
assign forw_csr[1] = forward_data2[`FORWAED_BUS_WD-1] && forward_data2[84] && use_csr_data && ~|(forward_data2[83:70]^csr_addr);
assign csr_rdata = forw_csr[0] ? forward_data1[69:38] : forw_csr[1] ? forward_data2[69:38] : csr_rdata_t;
assign csr_wdata_t = (rj_value & rkd_value) | (~rj_value & csr_rdata);
assign csr_wdata = use_mark ?  csr_wdata_t : rkd_value;

//regfile forward|
assign forw_rj[0]  = forward_data1[`FORWAED_BUS_WD-1] && forward_data1[37]   && ~|(forward_data1[36:32]^rf_raddr1);
assign forw_rj[1]  = forward_data2[`FORWAED_BUS_WD-1] && forward_data2[37]   && ~|(forward_data2[36:32]^rf_raddr1);
assign forw_rkd[0] = forward_data1[`FORWAED_BUS_WD-1] && forward_data1[37]   && ~|(forward_data1[36:32]^rf_raddr2);
assign forw_rkd[1] = forward_data2[`FORWAED_BUS_WD-1] && forward_data2[37]   && ~|(forward_data2[36:32]^rf_raddr2);
assign rj_value  = forw_rj[1] ? forward_data2[31:0] : forw_rj[0] ? forward_data1[31:0] : rj_value_t;
assign rkd_value = forw_rkd[1]? forward_data2[31:0] : forw_rkd[0]? forward_data1[31:0] : rkd_value_t;
//regfile forward|
assign forw_rj[0]  = forward_data1[`FORWAED_BUS_WD-1] && forward_data1[37]  && ~|(forward_data1[36:32]^rf_raddr1);
assign forw_rj[1]  = forward_data2[`FORWAED_BUS_WD-1] && forward_data2[37]  && ~|(forward_data2[36:32]^rf_raddr1);
assign forw_rkd[0] = forward_data1[`FORWAED_BUS_WD-1] && forward_data1[37]  && ~|(forward_data1[36:32]^rf_raddr2);
assign forw_rkd[1] = forward_data2[`FORWAED_BUS_WD-1] && forward_data2[37]  && ~|(forward_data2[36:32]^rf_raddr2);
assign rj_value  = forw_rj[1] ? forward_data2[31:0] : forw_rj[0] ? forward_data1[31:0] : rj_value_t;
assign rkd_value = forw_rkd[1]? forward_data2[31:0] : forw_rkd[0]? forward_data1[31:0] : rkd_value_t;

//src
assign src1 = src1_is_pc ? es_pc : rj_value;
assign src2 = src2_is_imm ? imm : src2_is_4 ? 32'h4 : rkd_value;

assign final_result = (state==wait_an_state && another_ok) ? temp_r : use_csr_data ? csr_rdata : res_from_mem ? mem_result : use_div ? div_result : use_mul ? mul_result : alu_result;

//for mem
assign es_to_ms_bus = {
    flush_icache& cacop_valid & ds_to_es_valid,
    flush_dcache& cacop_valid & ds_to_es_valid,
    cacop_code, 
    alu_result, 
    is_unsigned, 
    mem_we&&cal_valid&&!in_excp_t, 
    res_from_mem&cal_valid&!in_excp_t, 
    bit_width, 
    rkd_value,
     es_pc};
assign {cacop_ok, dcache_ok, mem_result} = ms_to_es_bus;

//flush: jump or excp or etrn 
assign flush = (pre_fail || excp_jump && ~jump_excp_fail && (is_etrn || in_excp)) && ds_to_es_valid;
assign jump_target = (excp_jump &(in_excp || is_etrn)) ? excp_pc : branch_target;
assign flush_IF = flush;
assign flush_ID = flush;
assign br_bus = reset ? 0 : {flush, jump_target};

//csr
assign is_etrn = is_etrn_t&ds_to_es_valid;
assign in_excp = (in_excp_t | (excp_ale & (mem_we | res_from_mem)))&ds_to_es_valid;
assign excp_Ecode = (in_excp_t) ? excp_Ecode_t : 6'h9;
assign excp_subEcode = (in_excp_t) ? excp_subEcode_t : 9'h0;
assign use_badv = (in_excp_t) ? use_badv_t : excp_ale; 
assign bad_addr = (in_excp_t) ? bad_addr_t : alu_result;
assign csr_bus = {is_etrn, in_excp, excp_Ecode, excp_subEcode, es_pc,use_badv, bad_addr};

//for div
assign es_to_div_bus = {use_div && cal_valid && !in_excp_t , use_mod, is_unsigned, src1, src2};
assign {div_result, div_ok} = div_to_es_bus;

//for mul
assign es_to_mul_bus = {use_mul && cal_valid && !in_excp_t , use_high, is_unsigned, src1, src2};
assign {mul_result, mul_ok} = mul_to_es_bus;

assign bpu_es_bus = {flush, es_pc, may_jump&cal_valid&!in_excp&!is_etrn, need_jump&cal_valid, pre_fail&cal_valid, jump_target, jump_type};

Alu u_alu (
    .alu_op    (alu_op),
    .alu_src1  (src1),
    .alu_src2  (src2),
    .alu_result(alu_result),
    .zero      (zero),
    .less      (less)
);

BranchCond u_branch (
    .pre_jump(is_jump),
    .may_jump(may_jump),
    .use_rj_value(use_rj_value),
    .use_less(use_less),
    .need_less(need_less),
    .use_zero(use_zero),
    .need_zero(need_zero),
    .less(less),
    .zero(zero),
    .pc(es_pc),
    .rj_value(rj_value),
    .need_jump(need_jump),
    .jump_target(branch_target),
    .imm(imm),
    .pre_fail(pre_fail)
);


endmodule
