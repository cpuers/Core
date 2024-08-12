`ifndef DEFINE_VH
`define DEFINE_VH

`define FS_ICACHE_WD 128
`define FS_ES_BUS_WD 114
//for InstrBuffer
`define IB_WIDTH 8
`define IB_WIDTH_LOG2 3

`define IB_DATA_BUS_WD 81
`define DS_TO_ES_BUS_WD 246
// 流水线寄存器位宽
`define IF0_TO_IF1_BUS_WD 56

`define CSR_BUS_WD 82 
//执行阶段旁路信息
`define FORWAED_BUS_WD 86

`define BR_BUS_WD 33
`define ES_TO_WS_BUS_WD 117

`define ES_TO_MS_BUS_WD 103
`define MS_TO_ES_BUS_WD 33
`define EXM_DCACHE_RD 34
`define EXM_DCACHE_WD 106

//写回寄存器信息
`define WS_TO_RF_BUS_WD 140

`define BPU_ES_BUS_WD 70

`define ES_TO_DIV_BUS_MD 67
`define DIV_TO_ES_BUS_MD 33
`define ES_TO_MUL_BUS_MD 67
`define MUL_TO_ES_BUS_MD 33

`ifdef DIFFTEST_EN
`define DS_ES_DEBUG_BUS_WD 57
`define ES_WS_DEBUG_BUS_WD 288
`define WS_DEBUG_BUS_WD 353
`define MUL_USE_WALLACE
`endif 

`endif
