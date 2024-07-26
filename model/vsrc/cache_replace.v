module replace_rand_2 (
    input               clock,
    input               reset,
    input               en,
    input       [ 1:0]  valid_way,
    output  reg [ 1:0]  replace_en  // combinational logic
);
    wire                selector;
    always @(*) begin
        case (valid_way)
            2'b00: begin
                replace_en = 2'b10;
            end
            2'b01: begin
                replace_en = 2'b10;
            end
            2'b10: begin
                replace_en = 2'b01;
            end
            2'b11: begin
                replace_en = selector ? 2'b10 : 2'b01;
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
    input       [ 1:0]  valid_way,
    input       [ 0:0]  lru_in,
    output  reg [ 1:0]  replace_en
);
    always @(*) begin
        case (valid_way)
            2'b00: begin
                replace_en = 2'b10;
            end
            2'b01: begin
                replace_en = 2'b10;
            end
            2'b10: begin
                replace_en = 2'b01;
            end
            2'b11: begin
                replace_en = lru_in ? 2'b01 : 2'b10;
            end
        endcase
    end
endmodule
