`define PERF_CNT_PORT(x) \
    input           ``x``,

`define PERF_CNT_REG(x) \
    reg     [63:0]  ``x``_cnt; \
    always @(posedge clock) begin \
        if (reset) begin \
            ``x``_cnt <= 0; \
        end else begin \
            if (``x``) begin \
                ``x``_cnt <= ``x``_cnt + 1; \
            end \
        end \
    end

`define PERF_CNTS(f) \
    `f(ifetch) \
    `f(ifetch_hit) \
    `f(load) \
    `f(load_hit) \
    `f(store) \
    `f(store_hit) \
    `f(jump) \
    `f(jump_correct) \
    `f(jump_correct_target)

module perf_counter(
    `PERF_CNTS(PERF_CNT_PORT)

    input       clock,
    input       reset
);
    `PERF_CNTS(PERF_CNT_REG)
endmodule
