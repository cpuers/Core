module mux2_1(
    input   a, b,
    input   sel,
    output  f
);
    assign f = sel ? b : a;
endmodule
