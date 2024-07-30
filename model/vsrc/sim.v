`ifdef TEST

module sram_sim #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16
) (
    input                       clka,
    input                       ena,
    input                       wea,
    input   [ADDR_WIDTH-1:0]    addra,
    input   [DATA_WIDTH-1:0]    dina,
    output  [DATA_WIDTH-1:0]    douta
);
    reg     [DATA_WIDTH-1:0]    mem     [0:(1<<ADDR_WIDTH)-1];
    reg     [DATA_WIDTH-1:0]    buffer;

    initial begin
        integer i;
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clka) begin
        buffer <= 0;
        if (ena) begin
            buffer <= mem[addra];
            if (wea) begin
                buffer <= dina;
                mem[addra] <= dina;
            end
        end
    end

    assign douta = buffer;
endmodule

module sram_sim_strb #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16,
    parameter STRB_WIDTH = DATA_WIDTH / 8
) (
    input                       clka,
    input                       ena,
    input   [STRB_WIDTH-1:0]    wea,
    input   [ADDR_WIDTH-1:0]    addra,
    input   [DATA_WIDTH-1:0]    dina,
    output  [DATA_WIDTH-1:0]    douta
);
    reg     [DATA_WIDTH-1:0]    mem     [0:(1<<ADDR_WIDTH)-1];
    reg     [DATA_WIDTH-1:0]    buffer;
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clka) begin
        buffer <= 0;
        if (ena) begin
            buffer <= mem[addra];
            for (i = 0; i < STRB_WIDTH; i = i + 1) begin
                if (wea[i]) begin
                    mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
                    buffer[i*8 +: 8] <= dina[i*8 +: 8];
                end
            end
        end
    end

    assign douta = buffer;
endmodule

`endif
