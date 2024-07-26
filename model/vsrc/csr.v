`include "csr.vh"
module csr (
    input clk,
    input rst,

    //for ID
    input [13:0] csr_addr,
    output  reg [31:0] csr_data,
    
    //TODO
    input [13:0] csr_waddr,
    input csr_wen,
    input [31:0] wdata
);
    reg [31:0] csr_crmd;
    reg [31:0] csr_prmd;
    reg [31:0] csr_estat;
    reg [31:0] csr_era;
    reg [31:0] csr_eentry;
    reg [31:0] csr_save0;
    reg [31:0] csr_save1;
    reg [31:0] csr_save2;
    reg [31:0] csr_save3;
    reg [31:0] test;

    always @(*) 
    begin
        case (csr_addr)
            `CRMD: csr_data = csr_crmd;
            `PRMD: csr_data = csr_prmd;
            `ESTAT: csr_data = csr_estat;
            `ERA: csr_data = csr_era;   
            `EENTRY:csr_data = csr_eentry;
            `SAVE0: csr_data = csr_save0;
            `SAVE1: csr_data = csr_save1;
            `SAVE2: csr_data = csr_save2;
            `SAVE3: csr_data = csr_save3;
        default: 
            csr_data = 32'h0;
        endcase    
    end

    always @(posedge clk) 
    begin
        if (rst) 
        begin
            csr_crmd[`PLV] <=2'b0;
            csr_crmd[`IE] <= 1'b0;
            csr_crmd[`DA] <= 1'b1;
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
        else
        begin
            csr_crmd <= csr_crmd;
        end    
    end
    
    always @(posedge clk)
    begin
        if (rst)
        begin
            csr_prmd[`PRMD_REV] <= 29'h0;
        end
        else if (csr_wen && (csr_waddr == `PRMD))
        begin
            csr_prmd[`PPLV] <= wdata[`PPLV];
        end 
    end

    always @(posedge clk) 
    begin
        if(rst)
        begin
            csr_estat[`ESTAT_REV0] <= 1'b0;
            csr_estat[`ESTAT_REV1] <= 3'b0;
            csr_estat[`ESTAT_REV2] <= 1'b0;
            csr_estat[`IS_SOFT] <= 2'b0;
        end
        else if(csr_wen && (csr_waddr==`ESTAT))
        begin
            csr_estat[`IS_SOFT] <= wdata[`IS_SOFT];
            
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
    end

    always @(posedge clk ) 
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
            csr_save0 <= 32'h0;
        end
        else if (csr_wen && (csr_waddr == `SAVE3))
        begin
            csr_save3 <= wdata;
        end
    end

endmodule
