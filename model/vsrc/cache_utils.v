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
    output  reg         need_send
);
    wire                selector;
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
                        way_replace_en = selector ? 2'b10: 2'b01;
                    end 
                    2'b01: begin
                        way_replace_en = 2'b10;
                    end
                    2'b10: begin
                        way_replace_en = 2'b01;
                    end
                    2'b11: begin
                        way_replace_en = selector ? 2'b10: 2'b01;
                        need_send = 1'b1;
                    end
                endcase
            end
        endcase
    end

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
