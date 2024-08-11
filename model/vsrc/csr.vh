`include "config.vh"
`define CRMD 14'h0
`define PLV 1:0
`define IE 2
`define DA 3
`define PG 4
`define DATF 6:5
`define DATM 8:7
`define CRMD_REV 31:9

`define PRMD 14'h1
`define PPLV 1:0
`define PIE 2
`define PRMD_REV 31:3

`define ESTAT 14'h5
`define IS_SOFT 1:0
`define IS_HARD 9:2
`define ESTAT_REV0 10
`define IS_TI 11
`define IS_IPI 12
`define ESTAT_REV1 15:13
`define Ecode   21:16
`define EsubCode    30:22
`define ESTAT_REV2 31

`define ERA 14'h6
`define ERA_PC 31:0

`define EENTRY 14'hc
`define EENTRY_0 5:0
`define VA     31:6

`define SAVE0 14'h30 
`define SAVE1 14'h31 
`define SAVE2 14'h32 
`define SAVE3 14'h33 
`define SAVE_data 31:0

`define ECFG 14'h4
`define LIE_9_0 9:0
`define ECFG_REV0 10
`define LIE_12_11 12:11
`define ECFG_REV1 31:13

`define BADV 14'h7
`define VAddr 31:0

`define TID 14'h40

`define TCFG 14'h41
`define En 0
`define Periodic 1
`define InitVal 31:2

`define TVAL 14'h42

`define TICLR 14'h44
`define CLR 0
`define TICLR_REV 31:1

`define TLBIDX 14'h10
`define Index  $clog2(`TLBENTRY)-1:0
`define TLBIDX_REV0 15:$clog2(`TLBENTRY)
`define TLBIDX_REV1 23:16
`define PS 29:24
`define TLBIDX_REV2 30
`define NE 31

`define TLBEHI 14'h11
`define TLBEHI_REV0 12:0
`define TLBEHI_VPPN 31:13

`define TLBLO0 14'h12
`define TLBLO1 14'h13
`define TLBLO_V 0
`define TLBLO_D 1
`define TLBLO_PLV 3:2
`define TLBLO_MAT 5:4
`define TLBLO_G 6
`define TLBLO_REV0 7
`define TLBLO_PPN 27:8
`define TLBLO_REV1 31:28

`define ASID 14'h18
`define ASID_ASID 9:0
`define ASID_REV0 15:10
`define ASID_ASIDBITS 23:16
`define ASID_REV1 31:24

`define TLBRENTRY 14'h88
`define TLBRENTRY_REV0 5:0
`define TLBRENTRY_PA 31:6
// It's UB
`define TIMER_64_H 14'h99
`define TIMER_64_L 14'h9a
