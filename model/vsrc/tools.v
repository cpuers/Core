/* verilator lint_off DECLFILENAME */
module encoder_4_2(
    input  [3:0] in,
    output [1:0] out
);

assign out = {2{in[0]}} & 2'd0 |
	     {2{in[1]}} & 2'd1 |
	     {2{in[2]}} & 2'd2 |
	     {2{in[3]}} & 2'd3 ;

endmodule

module encoder_16_4(
    input  [15:0] in,
    output [ 3:0] out
);

wire [1:0] out_0, out_1, out_2, out_3;

encoder_4_2 one (.in(in[ 3: 0]), .out(out_0));
encoder_4_2 two (.in(in[ 7: 4]), .out(out_1));
encoder_4_2 thr (.in(in[11: 8]), .out(out_2));
encoder_4_2 fou (.in(in[15:12]), .out(out_3));

assign out = {4{|in[ 3: 0]}} & {2'd0, out_0} |
	     {4{|in[ 7: 4]}} & {2'd1, out_1} |		
	     {4{|in[11: 8]}} & {2'd2, out_2} |		
	     {4{|in[15:12]}} & {2'd3, out_3} ;		

endmodule
