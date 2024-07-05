module mux4_2 (
    input           a, b, c, d,
    input   [1:0]   sel,
    output          f
);
    wire    [1:0]   l;

    mux2_1 t0(.a(a), .b(b), .sel(sel[0]), .f(l[0]));
    mux2_1 t1(.a(c), .b(d), .sel(sel[0]), .f(l[1]));
    mux2_1 t2(.a(l[0]), .b(l[1]), .sel(sel[1]), .f(f));
endmodule
