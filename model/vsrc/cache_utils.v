module replace_1 (
    /* verilator lint_off UNUSED */
    input               clock,
    input               reset,
    input               en,
    /* verilator lint_on UNUSED */
    input       [ 0:0]  way_v,
    input       [ 0:0]  way_d,
    output  reg [ 0:0]  way_replace_en,
    output  reg         need_send
    );
    always @(*) begin
        need_send = 1'b0;
        way_replace_en = 1'b1;
        if (way_v && way_d) begin
            need_send = 1'b1;
        end
    end
endmodule

module replace_rand_2 (
    input               clock,
    input               reset,
    input               en,
    input       [ 1:0]  way_v,
    input       [ 1:0]  way_d,
    output  reg [ 1:0]  way_replace_en,  // combinational logic
    output              need_send
);
    wire                selector;
    always @(*) begin
        case (way_v)
            2'b00: begin
                way_replace_en = 2'b10;
            end
            2'b01: begin
                way_replace_en = 2'b10;
            end
            2'b10: begin
                way_replace_en = 2'b01;
            end
            2'b11: begin
                way_replace_en = selector ? 2'b01 : 2'b10;
            end
        endcase
    end
    assign need_send = |(way_replace_en & way_d);

    reg     [ 2:0]      lsfr;
    always @(posedge clock) begin
        if (reset) begin
            lsfr <= 3'b1;
        end else if (en) begin
            lsfr <= {lsfr[0]^lsfr[1], lsfr[2:1]};
        end else begin
            lsfr <= lsfr;
        end
    end
    assign selector = lsfr[0];
endmodule

module replace_rand_4 (
    input               clock,
    input               reset,
    input               en,
    input       [ 3:0]  way_v,
    input       [ 3:0]  way_d,
    output  reg [ 3:0]  way_replace_en,
    output              need_send
    );
    integer i;
    reg accu;

    always @(*) begin
        way_replace_en = 4'b0;
        accu = 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            way_replace_en[i] = ~accu & ~way_v[i];
            accu = accu | way_replace_en[i];
        end
        if (way_replace_en == 4'b0) begin
            way_replace_en[lsfr[1:0]] = 1'b1;
        end
    end
    assign need_send = |(way_replace_en & way_d);

    reg         [ 2:0]  lsfr;
    always @(posedge clock) begin
        if (reset) begin
            lsfr <= 3'b1;
        end else if (en) begin
            lsfr <= {lsfr[0]^lsfr[1], lsfr[2:1]};
        end else begin
            lsfr <= lsfr;
        end
    end
endmodule

module replace_lru_4(
    /* verilator lint_off UNUSED */
    input               clock,
    input               reset,
    input               en,
    /* verilator lint_on UNUSED */
    input       [ 3:0]  way_v,
    input       [ 3:0]  way_d,
    input       [ 0:0]  lru_o0,
    input       [ 1:0]  lru_o1,
    output  reg [ 3:0]  way_replace_en,
    output              need_send
    );
    integer i;
    reg accu;

    reg         [ 1:0]  selector;

    always @(*) begin
        if (lru_o0 ^ ^lru_o1 === 1'bx) begin
            selector = 2'b0;
        end else begin
            selector[1] = lru_o0;
            selector[0] = lru_o1[lru_o0];
        end
    end

    always @(*) begin
        way_replace_en = 4'b0;
        accu = 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            way_replace_en[i] = ~accu & ~way_v[i];
            accu = accu | way_replace_en[i];
        end
        if (way_replace_en == 4'b0) begin
            way_replace_en[selector] = 1'b1;
        end
    end
    assign need_send = |(way_replace_en & way_d);
endmodule

module replace_lru_2 (
    /* verilator lint_off UNUSED */
    input               clock,
    input               reset,
    input               en,
    /* verilator lint_on UNUSED */
    input       [ 1:0]  way_v,
    input       [ 1:0]  way_d,
    input       [ 0:0]  lru,
    output  reg [ 1:0]  way_replace_en,
    output  reg         need_send
);
    always @(*) begin
        need_send = 1'b0;
        case (way_v)
            2'b00: begin
                way_replace_en = 2'b10;
            end
            2'b01: begin
                way_replace_en = 2'b10;
            end
            2'b10: begin
                way_replace_en = 2'b01;
            end
            2'b11: begin
                case (way_d)
                    2'b00: begin
                        way_replace_en = lru ? 2'b01 : 2'b10;
                    end
                    2'b01: begin
                        way_replace_en = 2'b10;
                    end
                    2'b10: begin
                        way_replace_en = 2'b01;
                    end
                    2'b11: begin
                        need_send = 1'b1;
                        way_replace_en = lru ? 2'b01 : 2'b10;
                    end
                endcase
            end
        endcase
    end
endmodule

module wstrb_mixer(
    input               en,
    input   [31:0]      x,
    input   [31:0]      y,
    input   [ 3:0]      wstrb,
    output  [31:0]      f
    );

    reg     [31:0]      mask;
    integer i;
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            mask[i*8 +: 8] = {8{wstrb[i]}};
        end
    end

    assign f = (en) ? ((mask & x) | (~mask & y)) : y;
endmodule

module strb2size(
    /* verilator lint_off UNUSED */
    input       [ 3:0]  strb,
    /* verilator lint_on UNUSED */
    input       [ 1:0]  off,
    output reg  [ 2:0]  size // 2^size
    );

    always @(*) begin
        case (off)
            2'd0: begin
                if (strb[3]) begin
                    size = 3'd2;
                end else if (strb[1]) begin
                    size = 3'd1;
                end else begin
                    size = 3'd0;
                end
            end 
            2'd1: begin
                size = 3'd0;
            end
            2'd2: begin
                if (strb[3]) begin
                    size = 3'd1;
                end else begin
                    size = 3'd0;
                end
            end
            2'd3: begin
                size = 3'd0;
            end
        endcase    
    end
endmodule
