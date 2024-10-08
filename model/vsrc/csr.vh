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


// It's UB
`define TIMER_64_H 14'h99
`define TIMER_64_L 14'h9a
