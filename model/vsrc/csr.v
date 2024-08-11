`include "csr.vh"
`include "define.vh"
module csr (
    input clk,
    input rst,

    output csr_datf,
    output csr_datm, 
    //for ID
    output tlbrd_csr_install,
    input [13:0] csr_addr1,
    output  reg [31:0] csr_data1,
    input [13:0] csr_addr2,
    output  reg [31:0] csr_data2,
    
    //TODO
    input [13:0] csr_waddr,
    input csr_wen,
    input [31:0] wdata,

    //FOR EXE
    input [`CSR_BUS_WD -1:0] csr_bus,
    output jump_excp_fail,

    output excp_jump,
    output [31:0] excp_pc,

    //intrpt
    output have_intrpt,
    input [7:0] intrpt,


    input is_tlbsrch,
    input [$clog2(`TLBENTRY)-1:0] tlb_srch_idx,
    input tlb_srch_valid,

    output [18:0] csr_vppn,
    output [9:0]  tlb_csr_asid,

    //for TLB read
    input is_tlbrd,
    output [$clog2(`TLBENTRY)-1:0] tlb_r_idx,
    input [18:0]  tlb_r_vppn,
    input [9:0]  tlb_r_asid,
    input [5:0]  tlb_r_ps,
    input        tlb_r_e,
    input [27:0] tlb_r_lbelo0,
    input [27:0] tlb_r_lbelo1,

    //for TLB write
    input                           is_tlbwr,
    output                          tlb_w_en,
    output  [$clog2(`TLBENTRY)-1:0] tlb_w_idx,
    output  [18:0]                  tlb_w_vppn,
    output  [ 5:0]                  tlb_w_ps,
    output  [ 9:0]                  tlb_w_asid,
    output                          tlb_w_e,
    output  [27:0]                  tlb_w_tlbelo0,
    output  [27:0]                  tlb_w_tlbelo1

);
    wire in_excp;
    wire [5:0]excp_Ecode;
    wire [8:0] excp_subEcode;
    wire [31:0] excp_era;
    wire is_etrn;
    wire tval_is_nzero;
    wire [31:0] bad_vaddr;
    wire use_badv;
    wire rd_valid;
    wire rd_invalid;

    wire srch_valid = is_tlbsrch & tlb_srch_valid &~csr_wen;
    wire srch_invalid = is_tlbsrch & ~tlb_srch_valid &~csr_wen;

    assign {is_etrn, in_excp,excp_Ecode,excp_subEcode,excp_era,use_badv,bad_vaddr} = csr_bus;
    reg [31:0] csr_crmd;
    reg [31:0] csr_prmd;
    reg [31:0] csr_estat;
    reg [31:0] csr_era;
    reg [31:0] csr_eentry;
    reg [31:0] csr_save0;
    reg [31:0] csr_save1;
    reg [31:0] csr_save2;
    reg [31:0] csr_save3;
    reg [31:0] csr_ecfg;
    reg [31:0] csr_tid;
    reg [31:0] csr_tcfg;
    reg [31:0] csr_tval;
    reg [31:0] csr_badv;
    reg [63:0] csr_timer_64;
    reg [31:0] csr_tlbidx;
    reg [31:0] csr_tlbehi;
    reg [31:0] csr_tlblo0;
    reg [31:0] csr_tlblo1;
    reg [31:0] csr_asid;
    reg [31:0] csr_tlbrentry;
    reg timer_en;

    
    assign jump_excp_fail = csr_wen& in_excp;
    assign csr_datf = csr_wen && (csr_waddr == `CRMD) ? wdata[5] : csr_crmd[5];
    assign csr_datm = csr_wen && (csr_waddr == `CRMD) ? wdata[7] : csr_crmd[7];
    assign excp_jump = (in_excp | is_etrn) & ~jump_excp_fail;
    assign excp_pc = in_excp ? csr_eentry :
                     csr_wen &(csr_waddr==`ERA) ? wdata :  csr_era;
    assign excp_pc = in_excp ? csr_eentry :
                     csr_wen &(csr_waddr==`ERA) ? wdata :  csr_era;
    assign have_intrpt = csr_crmd[`IE] &|(csr_ecfg[12:0]&csr_estat[12:0]);
    
    assign rd_valid = is_tlbrd & tlb_r_e &!csr_wen;
    assign rd_invalid = is_tlbrd & !tlb_r_e &!csr_wen;

    assign tlb_r_idx = csr_tlbidx[`Index];
    assign tlb_w_en = is_tlbwr & !csr_wen;
    assign tlb_w_idx = csr_tlbidx[`Index];
    assign tlb_w_vppn = csr_tlbehi[`TLBEHI_VPPN];
    assign tlb_w_ps = csr_tlbidx[`PS];
    assign tlb_w_asid = csr_asid[`ASID_ASID];
    assign tlb_w_e = (csr_estat[`Ecode] == 6'h3f)| ~csr_tlbidx[`NE]; 
    assign tlb_w_tlbelo0 = csr_tlblo0[27:0];
    assign tlb_w_tlbelo1 = csr_tlblo1[27:0];
    
    assign csr_vppn = csr_tlbehi[`TLBEHI_VPPN];
    assign tlb_csr_asid = csr_asid[`ASID_ASID];
    
    assign tlbrd_csr_install = csr_wen & (is_tlbrd|is_tlbwr|is_tlbsrch);

    always @(*) 
    begin
        case (csr_addr1)
            `CRMD: csr_data1 = csr_crmd;
            `PRMD: csr_data1 = csr_prmd;
            `ESTAT: csr_data1 = csr_estat;
            `ERA: csr_data1 = csr_era;   
            `EENTRY:csr_data1 = csr_eentry;
            `SAVE0: csr_data1 = csr_save0;
            `SAVE1: csr_data1 = csr_save1;
            `SAVE2: csr_data1 = csr_save2;
            `SAVE3: csr_data1 = csr_save3;
            `ECFG: csr_data1 = csr_ecfg;
            `TID: csr_data1 = csr_tid;
            `TCFG: csr_data1 = csr_tcfg;
            `TVAL: csr_data1 = csr_tval;
            `BADV: csr_data1 = csr_badv;
            `TIMER_64_H: csr_data1 = csr_timer_64[63:32];
            `TIMER_64_L: csr_data1 = csr_timer_64[31:0];
            `TLBIDX: csr_data1 = csr_tlbidx;
            `TLBEHI: csr_data1 = csr_tlbehi;
            `TLBLO0: csr_data1 = csr_tlblo0;
            `TLBLO1: csr_data1 = csr_tlblo1;
            `ASID: csr_data1 = csr_asid;
            `TLBRENTRY: csr_data1 = csr_tlbrentry;
        default: 
            csr_data1 = 32'h0;
        endcase    
    end

    always @(*) 
    begin
        case (csr_addr2)
            `CRMD: csr_data2 = csr_crmd;
            `PRMD: csr_data2 = csr_prmd;
            `ESTAT: csr_data2 = csr_estat;
            `ERA: csr_data2 = csr_era;   
            `EENTRY:csr_data2 = csr_eentry;
            `SAVE0: csr_data2 = csr_save0;
            `SAVE1: csr_data2 = csr_save1;
            `SAVE2: csr_data2 = csr_save2;
            `SAVE3: csr_data2 = csr_save3;
            `ECFG: csr_data2  = csr_ecfg;
            `TID: csr_data2 = csr_tid;
            `TCFG: csr_data2 = csr_tcfg;
            `TVAL:csr_data2 = csr_tval;
            `BADV: csr_data2 = csr_badv;
            `TIMER_64_L: csr_data2 = csr_timer_64[31:0];
            `TIMER_64_H: csr_data2 = csr_timer_64[63:32];
            `TLBIDX: csr_data2 = csr_tlbidx;
            `TLBEHI: csr_data2 = csr_tlbehi;           
            `TLBLO0: csr_data2 = csr_tlblo0;
            `TLBLO1: csr_data2 = csr_tlblo1;
            `ASID: csr_data2 = csr_asid;
            `TLBRENTRY: csr_data2 = csr_tlbrentry;
        default: 
            csr_data2 = 32'h0;
        endcase    
    end

    //crmd
    
        
    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            timer_en <= 1'b0; 
        end    
        else if (csr_wen && (csr_waddr==`TCFG))
        begin
            timer_en <= wdata[`En];
        end
        else if(timer_en && ~tval_is_nzero)
        begin
            timer_en <= csr_tcfg[`Periodic];
        end
    end
    
        
    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            timer_en <= 1'b0; 
        end    
        else if (csr_wen && (csr_waddr==`TCFG))
        begin
            timer_en <= wdata[`En];
        end
        else if(timer_en && ~tval_is_nzero)
        begin
            timer_en <= csr_tcfg[`Periodic];
        end
    end
    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_crmd[`PLV] <=2'b0;
            csr_crmd[`IE] <= 1'b0;
            csr_crmd[`DA] <= 1'b1;
            csr_crmd[`PG] <= 1'b0;
            csr_crmd[`DATF] <= 2'b0;
            csr_crmd[`DATM] <= 2'b0;
            csr_crmd[`CRMD_REV] <= 23'b0;     
                     
                     
        end
        else if(csr_wen && (csr_waddr == `CRMD))
        begin
            csr_crmd[`PLV] <= wdata[`PLV];
            csr_crmd[`IE] <= wdata[`IE];
            csr_crmd[`DA] <= wdata[`DA];
            csr_crmd[`PG] <= wdata[`PG];
            csr_crmd[`DATF] <= wdata[`DATF];
            csr_crmd[`DATM] <= wdata[`DATM];
        end
        else if (in_excp) 
        begin
            csr_crmd[`PLV] <=    2'b0;
            csr_crmd[`IE] <= 1'b0;
        end
        else if(is_etrn)
        begin
            csr_crmd[`PLV] <= csr_prmd[`PPLV];
            csr_crmd[`IE] <= csr_prmd[`PIE];
        end  
    end

    //prmd
    always @(posedge clk)
    begin
        if (rst)
        begin
            csr_prmd[`PRMD_REV] <= 29'h0;
        end
        else if (csr_wen && (csr_waddr == `PRMD))
        begin
            csr_prmd[`PPLV] <= wdata[`PPLV];
            csr_prmd[`PIE] <= wdata[`PIE];
        end
        else if (in_excp&!csr_wen)
        begin
            csr_prmd[`PPLV] <= csr_crmd[`PLV];
            csr_prmd[`PIE] <= csr_crmd[`IE];
        end 
    end

    //estat
    always @(posedge clk) 
    begin
        if(rst)
        begin
            csr_estat <= 32'h0;
        end
        else if(csr_wen && (csr_waddr==`ESTAT))
        begin
            csr_estat[`IS_SOFT] <= wdata[`IS_SOFT];
        end
        else if(in_excp &!csr_wen)
        begin
            csr_estat[`Ecode] <= excp_Ecode;
            csr_estat[`EsubCode] <= excp_subEcode;
        end
        csr_estat[`IS_HARD] <= intrpt;

        if(timer_en & !tval_is_nzero)
        begin
            csr_estat[`IS_TI] <=1'b1;
        end
        else if (csr_wen &csr_waddr == `TICLR)
        begin
            csr_estat[`IS_TI] <= ~wdata[`CLR];
        end
    end

    always @(posedge clk) 
    begin
        if(rst)
        begin
            csr_era <= 32'h0;
        end
        else if (csr_wen && (csr_waddr==`ERA))
        begin
            csr_era <= wdata;
        end
        else if(in_excp&!csr_wen)
        begin
            csr_era <=excp_era;
        end

    end

    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_eentry <= 32'h0;    
        end
        else if(csr_wen && (csr_waddr ==`EENTRY))
        begin
            csr_eentry[`VA] <= wdata[`VA]; 
        end    
    end

    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_save0 <= 32'h0;
        end
        else if (csr_wen && (csr_waddr == `SAVE0))
        begin
            csr_save0 <= wdata;
        end
    end

    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_save1 <= 32'h0;
        end
        else if (csr_wen && (csr_waddr == `SAVE1))
        begin
            csr_save1 <= wdata;
        end
    end

    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_save2 <= 32'h0;
        end
        else if (csr_wen && (csr_waddr == `SAVE2))
        begin
            csr_save2 <= wdata;
        end
    end

    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_save3 <= 32'h0;
        end
        else if (csr_wen && (csr_waddr == `SAVE3))
        begin
            csr_save3 <= wdata;
        end
    end

    //ECFG

    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_ecfg <= 32'b0;    
        end
        if(csr_wen && (csr_waddr == `ECFG))
        begin
            csr_ecfg[`LIE_9_0] <= wdata[`LIE_9_0];
            csr_ecfg[`LIE_12_11] <= wdata[`LIE_12_11];
        end
    end

    //TID

    always @(posedge clk)
    begin
        if(rst)
        begin
            csr_tid <= 32'h0;
        end
        else if(csr_wen && (csr_waddr ==`TID))
        begin
            csr_tid <= wdata;
        end
    end

    //TCFG 
    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_tcfg <= 32'h0;    
        end
        if (csr_wen && (csr_waddr==`TCFG)) 
        begin
            csr_tcfg[`En] <= wdata[`En];
            
            
            csr_tcfg[`Periodic] <= wdata[`Periodic];
            csr_tcfg[`InitVal] <= wdata[`InitVal];
        end    
    end
    
    
    assign tval_is_nzero = |csr_tval;
    //TVAL
    always @(posedge clk) 
    begin
        if (rst)
        begin
            csr_tval <= 32'h0;
        end
        else if(csr_wen && (csr_waddr == `TCFG))
        begin
            csr_tval <= {wdata[`InitVal],2'b0};
        end
        else if(timer_en)
        begin
            if (tval_is_nzero) 
            begin
                csr_tval <= csr_tval - 32'b1;
            end
            else
            begin
                csr_tval <= csr_tcfg[`Periodic] ? {csr_tcfg[`InitVal],2'b0} : 32'h0;
                
                
            end
        end     
    end

    //BADV
    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_badv <= 32'h0;    
        end
        else if(in_excp & use_badv)
        begin
            csr_badv <= bad_vaddr;
        end    
    end

    //Timer_64;
    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_timer_64 <= 64'h0;    
        end 
        else
        begin
            csr_timer_64 <=csr_timer_64 + 64'h1;
        end   
    end

    //TLBIDX
    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_tlbidx <=32'h0;
        end
        else if(csr_wen && (csr_waddr == `TLBIDX))
        begin
            csr_tlbidx[`Index] <= wdata[`Index];
            csr_tlbidx[`PS] <=wdata[`PS];
            csr_tlbidx[`NE] <=wdata[`NE];
        end
        else if(rd_valid)
        begin
            csr_tlbidx[`PS]<= tlb_r_ps;
            csr_tlbidx[`NE] <= 1'b0;    
        end 
        else if(rd_invalid)
        begin
            csr_tlbidx[`PS] <= 6'b0;
            csr_tlbidx[`NE] <= 1'b1;
        end
        else if(srch_valid)
        begin
            csr_tlbidx[`Index] <= tlb_srch_idx;
            csr_tlbidx[`NE] <= 1'b0;
        end
        else if(srch_invalid)
        begin
            csr_tlbidx[`NE] <= 1'b1;
        end
   
    end

    //TLBEHI
    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_tlbehi <= 32'h0;    
        end
        else if(csr_wen && (csr_waddr == `TLBEHI))
        begin
            csr_tlbehi[`TLBEHI_VPPN] <= wdata[`TLBEHI_VPPN];
        end 
        else if(rd_valid)
        begin
            csr_tlbehi[`TLBEHI_VPPN] <= tlb_r_vppn;
        end
        else if(rd_invalid)    
        begin
            csr_tlbehi[`TLBEHI_VPPN] <= 19'h0;
        end
    end

    //TLBLO0

    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_tlblo0 <= 32'h0;
        end    
        else if(csr_wen && (csr_waddr == `TLBLO0))
        begin
            csr_tlblo0[`TLBLO_V] <= wdata[`TLBLO_V];
            csr_tlblo0[`TLBLO_D] <= wdata[`TLBLO_D];
            csr_tlblo0[`TLBLO_PLV] <= wdata[`TLBLO_PLV];
            csr_tlblo0[`TLBLO_MAT] <= wdata[`TLBLO_MAT];
            csr_tlblo0[`TLBLO_G] <= wdata[`TLBLO_G];
            csr_tlblo0[`TLBLO_PPN] <= wdata[`TLBLO_PPN];
        end
        else if(rd_valid)
        begin
            csr_tlblo0[27:0] <= tlb_r_lbelo0;
        end
        else if(rd_invalid)
        begin
            csr_tlblo0[27:0] <= 28'h0;
        end
    end

    //TLBLO1
    always @(posedge clk ) 
    begin
        if(rst)
        begin
            csr_tlblo1 <= 32'h0;
        end    
        else if(csr_wen && (csr_waddr == `TLBLO1))
        begin
            csr_tlblo1[`TLBLO_V] <= wdata[`TLBLO_V];
            csr_tlblo1[`TLBLO_D] <= wdata[`TLBLO_D];
            csr_tlblo1[`TLBLO_PLV] <= wdata[`TLBLO_PLV];
            csr_tlblo1[`TLBLO_MAT] <= wdata[`TLBLO_MAT];
            csr_tlblo1[`TLBLO_G] <= wdata[`TLBLO_G];
            csr_tlblo1[`TLBLO_PPN] <= wdata[`TLBLO_PPN];
        end
        else if(rd_valid)
        begin
            csr_tlblo1[27:0] <= tlb_r_lbelo1;
        end
        else if(rd_invalid)
        begin
            csr_tlblo1[27:0] <= 28'h0;
        end
    end

    //ASID

    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_asid[`ASID_ASID] <= 10'h0;
            csr_asid[`ASID_ASIDBITS] <= 8'd10;
            csr_asid[`ASID_REV0]<= 6'h0;
            csr_asid[`ASID_REV1] <= 8'h0;    
        end    
        else if(csr_wen && (csr_waddr == `ASID))
        begin
            csr_asid[`ASID_ASID] <= wdata[`ASID_ASID];
        end
        else if(rd_valid)
        begin
            csr_asid[`ASID_ASID] <= tlb_r_asid;
        end
        else if(rd_invalid)
        begin
            csr_asid[`ASID_ASID] <= 10'b0;
        end
    end

    //TLBRENTRY

    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_tlbrentry <= 32'h0;  
        end    
        else if(csr_wen && (csr_waddr == `TLBRENTRY))
        begin
            csr_tlbrentry[`TLBRENTRY_PA] <= wdata[`TLBRENTRY_PA];
        end
    end

endmodule

