`include "config.vh"
/* verilator lint_off DECLFILENAME */

module tlb_async (
    input           clock,
    input           reset,

    // translation: ifetch (current tick)
    input   [19:0]                  if_vpn,      // 虚拟页号
    input   [ 9:0]                  if_asid,     // 地址空间标识
    input   [ 1:0]                  if_priv,     // 访问权限
    output  [$clog2(`TLBENTRY)-1:0] if_idx,      // TLB索引
    output                          if_valid,    // 地址转换是否有效
    // high on unprivileged access
    output                          if_unpriv,   // 非特权访问标志(1->用户)
    output  [19:0]                  if_ppn,      // 物理页号
    output                          if_uncached, // 非缓存标志(1->直接访问内存)

    // translation: load / store (current tick)
    input   [19:0]                  ls_vpn,       
    input   [ 9:0]                  ls_asid,
    input   [ 1:0]                  ls_priv,
    output  [$clog2(`TLBENTRY)-1:0] ls_idx,
    output                          ls_valid,
    output                          ls_unpriv,
    output  [19:0]                  ls_ppn,
    output                          ls_uncached,

    // write (one tick)
    input                           w_en,
    input   [$clog2(`TLBENTRY)-1:0] w_idx,
    input   [18:0]                  w_vppn,
    input   [ 5:0]                  w_ps,       // 页大小
    input   [ 9:0]                  w_asid,     // 地址空间标识符
    input                           w_e,        // 写入有效
    input   [27:0]                  w_tlbelo0,  // 页表低位
    input   [27:0]                  w_tlbelo1,

    // read (current tick)
    input   [$clog2(`TLBENTRY)-1:0] r_idx,
    output  [18:0]                  r_vppn,
    output  [ 9:0]                  r_asid,
    output  [ 5:0]                  r_ps,
    output                          r_e,
    output  [27:0]                  r_tlbelo0,
    output  [27:0]                  r_tlbelo1,

    // invtlb (one tick)
    input           inv_en,
    input   [ 4:0]  inv_op,
    input   [ 9:0]  inv_asid,
    input   [18:0]  inv_vppn
);
    genvar i;
    integer j;

    // tlb
    reg     [18:0]      vppn    [0:`TLBENTRY-1];
    reg                 ps      [0:`TLBENTRY-1];
    reg     [ 9:0]      asid    [0:`TLBENTRY-1];
    reg                 e       [0:`TLBENTRY-1];
    reg     [27:0]      tlbelo0 [0:`TLBENTRY-1];
    reg     [27:0]      tlbelo1 [0:`TLBENTRY-1];

    wire                g       [0:`TLBENTRY-1];
    generate
        for (i = 0; i < `TLBENTRY; i = i + 1) begin
            assign g   [i]  = tlbelo0[i][6];
        end
    endgenerate

    // read
    assign r_vppn       = vppn      [r_idx];
    assign r_ps         = ps        [r_idx] ? 6'd21 : 6'd12;
    assign r_asid       = asid      [r_idx];
    assign r_e          = e         [r_idx];
    assign r_tlbelo0    = tlbelo0   [r_idx];
    assign r_tlbelo1    = tlbelo1   [r_idx];

    // ifetch
    wire [`TLBENTRY-1:0] if_hit;
    wire    [27:0]  if_sel_pg       [0:`TLBENTRY-1];
    reg     [27:0]  if_entry;                           // COMBINATION LOGIC
    generate
        for (i = 0; i < `TLBENTRY; i = i + 1) begin
            assign if_hit[i] = 
                e[i] && (vppn[i] == if_vpn[19:1]) &&
                (g[i] || asid[i] == if_asid);
            assign if_sel_pg[i] = (if_vpn[0] ? tlbelo1[i] : tlbelo0[i]);
        end
    endgenerate
    always @(*) begin
        if_entry = 0;        
        for (j = 0; j < `TLBENTRY; j ++) begin
            if_entry = if_entry | (if_sel_pg[j] & {28{if_hit[j]}});
        end
    end
    // assert `TLBENTRY == 16
    encoder_16_4    if_idx_enc(.in(if_hit), .out(if_idx));
    assign if_valid = |if_hit & if_entry[0];
    assign if_unpriv = if_entry[3:2] < if_priv;
    assign if_uncached = (if_entry[5:4] == 2'd0);
    assign if_ppn = if_entry[27:8];

    // load / store
    wire [`TLBENTRY-1:0] ls_hit;
    wire    [27:0]  ls_sel_pg       [0:`TLBENTRY-1];
    reg     [27:0]  ls_entry;                           // COMBINATION LOGIC
    generate
        for (i = 0; i < `TLBENTRY; i = i + 1) begin
            assign ls_hit[i] = 
                e[i] && (vppn[i] == ls_vpn[19:1]) &&
                (g[i] || asid[i] == ls_asid);
            assign ls_sel_pg[i] = (ls_vpn[0] ? tlbelo1[i] : tlbelo0[i]);
        end
    endgenerate
    always @(*) begin
        ls_entry = 0;        
        for (j = 0; j < `TLBENTRY; j ++) begin
            ls_entry = ls_entry | (ls_sel_pg[j] & {28{ls_hit[j]}});
        end
    end
    encoder_16_4    ls_idx_enc(.in(ls_hit), .out(ls_idx));
    assign ls_valid = |ls_hit & ls_entry[0];
    assign ls_unpriv = ls_entry[3:2] < ls_priv;
    assign ls_uncached = (ls_entry[5:4] == 2'd0);
    assign ls_ppn = ls_entry[27:8];

    // write & invtlb
    wire    sel     [0:`TLBENTRY-1];
    wire    w_g;
    assign w_g = w_tlbelo0[6] & w_tlbelo1[6];
    generate
        for (i = 0; i < `TLBENTRY; i ++) begin
            assign sel[i] =
                (w_en && w_idx == i) |
                (inv_en && (
                    (inv_op == 5'h0) |
                    (inv_op == 5'h1) |
                    (inv_op == 5'h2 && g[i]) |
                    (inv_op == 5'h3 && !g[i]) |
                    (inv_op == 5'h4 && !g[i] && asid[i] == inv_asid) |
                    (inv_op == 5'h5 && !g[i] && asid[i] == inv_asid 
                        && vppn[i] == inv_vppn) |
                    (inv_op == 5'h6 && g[i] && asid[i] == inv_asid
                        && vppn[i] == inv_vppn)
                ));
            always @(posedge clock) begin
                if (reset | (inv_en & sel[i])) begin
                    e[i] <= 1'b0;
                end
                else if (w_en) begin
                    if (sel[i]) begin
                        vppn[i] <= w_vppn;
                        ps[i] <= (w_ps == 6'd21);
                        asid[i] <= w_asid;
                        e[i] <= w_e;                     
                        tlbelo0[i] <= {w_tlbelo0[27:7], w_g, w_tlbelo0[5:0]};
                        tlbelo1[i] <= {w_tlbelo1[27:7], w_g, w_tlbelo1[5:0]};
                    end
                end
            end
        end
    endgenerate
endmodule
