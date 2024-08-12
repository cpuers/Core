`include "csr.vh"
`include "define.vh"
module csr (
    input clk,
    input rst,

    input [2:0]viaddrh,
    output iuncached,
    output [2:0]piaddrh,

    input [2:0]vdaddrh,
    output duncached,
    output [2:0]pdaddrh,
    output csr_datf,
    output csr_datm, 
    //for ID
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
    input [7:0] intrpt

    `ifdef DIFFTEST_EN
    ,
    output [31:0] csr_crmd_diff,
    output [31:0] csr_prmd_diff,
    output [31:0] csr_estat_diff,
    output [31:0] csr_era_diff,
    output [31:0] csr_eentry_diff,
    output [31:0] csr_save0_diff,
    output [31:0] csr_save1_diff,
    output [31:0] csr_save2_diff,
    output [31:0] csr_save3_diff,
    output [31:0] csr_ecfg_diff,
    output [31:0] csr_tid_diff,
    output [31:0] csr_tcfg_diff,
    output [31:0] csr_tval_diff,
    output [31:0] csr_badv_diff,
    output [63:0] csr_timer_64_diff,
    output [10:0] intrNo_diff,
    output [31:0] csr_dwm0_diff,    
    output [31:0] csr_dwm1_diff   
    `endif
);
    wire in_excp;
    wire [5:0]excp_Ecode;
    wire [8:0] excp_subEcode;
    wire [31:0] excp_era;
    wire is_etrn;
    wire tval_is_nzero;
    wire [31:0] bad_vaddr;
    wire use_badv;
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
    reg [31:0] csr_dwm0;
    reg [31:0] csr_dwm1;
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

    assign iuncached = csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == viaddrh) ? csr_dwm0[4] :
                        csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == viaddrh )? csr_dwm0[4] :
                        csr_crmd[5];
    
    assign piaddrh = csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == viaddrh) ? csr_dwm0[`DMW_PSEG] :
                        csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == viaddrh )? csr_dwm0[`DMW_PSEG] :
                        viaddrh;


    assign duncached = csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == vdaddrh) ? csr_dwm0[4] :
                        csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == vdaddrh )? csr_dwm0[4] :
                        csr_crmd[5];
    
    assign pdaddrh = csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == vdaddrh) ? csr_dwm0[`DMW_PSEG] :
                        csr_crmd[`PG] && (csr_dwm0[`DMW_VSEG] == vdaddrh )? csr_dwm0[`DMW_PSEG] :
                        vdaddrh;


        
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
            `DMW0: csr_data1 = csr_dwm0;
            `DMW1: csr_data1 = csr_dwm1;
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
            `DMW0: csr_data2 = csr_dwm0;
            `DMW1: csr_data2 = csr_dwm1;
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

    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_dwm0 <= 32'h0;    
        end
        else if(csr_wen && (csr_waddr == `DMW0))
        begin
            csr_dwm0[`DMW_PLV0] <= wdata[`DMW_PLV0];
            csr_dwm0[`DMW_PLV3] <= wdata[`DMW_PLV3];
            csr_dwm0[`DMW_MAT]  <= wdata[`DMW_MAT];
            csr_dwm0[`DMW_PSEG] <= wdata[`DMW_PSEG];
            csr_dwm0[`DMW_VSEG] <= wdata[`DMW_VSEG];
        end    
    end

    always @(posedge clk ) 
    begin
        if (rst) 
        begin
            csr_dwm1 <= 32'h0;    
        end
        else if(csr_wen && (csr_waddr == `DMW1))
        begin
            csr_dwm1[`DMW_PLV0] <= wdata[`DMW_PLV0];
            csr_dwm1[`DMW_PLV3] <= wdata[`DMW_PLV3];
            csr_dwm1[`DMW_MAT]  <= wdata[`DMW_MAT];
            csr_dwm1[`DMW_PSEG] <= wdata[`DMW_PSEG];
            csr_dwm1[`DMW_VSEG] <= wdata[`DMW_VSEG];
        end    
    end

    `ifdef DIFFTEST_EN
    assign csr_crmd_diff = csr_crmd;
    assign csr_prmd_diff = csr_prmd;
    assign csr_estat_diff = csr_estat;
    assign csr_era_diff = csr_era;
    assign csr_eentry_diff = csr_eentry;
    assign csr_save0_diff = csr_save0;
    assign csr_save1_diff = csr_save1;
    assign csr_save2_diff = csr_save2;
    assign csr_save3_diff = csr_save3;
    assign csr_ecfg_diff = csr_ecfg;
    assign csr_tid_diff = csr_tid;
    assign csr_tcfg_diff = csr_tcfg;
    assign csr_tval_diff = csr_tval;
    assign csr_badv_diff = csr_badv;
    assign csr_timer_64_diff = csr_timer_64;
    assign intrNo_diff = csr_estat[12:2];
    assign csr_dwm0_diff = csr_dwm0;
    assign csr_dwm1_diff = csr_dwm1;
    `endif
endmodule

