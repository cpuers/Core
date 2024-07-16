`ifndef DEFINE_H
`define DEFINE_H

`define FS_ICACHE_WD 128
`define FS_ES_BUS_WD 114
//for InstrBuffer
`define IB_WIDTH 16
`define IB_WIDTH_LOG2 4

`define IB_DATA_BUS_WD 68
`define DS_TO_ES_BUS_WD 177
// 流水线寄存器位宽
`define IF0_TO_IF1_BUS_WD 64
//执行阶段旁路信息
`define FORWAED_BUS_WD 37
//写回寄存器信息
`define WS_TO_RF_BUS_WD 76
`define BR_BUS_WD 33
`define ES_TO_WS_BUS_WD 70

`define BR_BUS_WD 33
`define ES_TO_WS_BUS_WD 70
`define EXM_DCACHE_RD 34
`define EXM_DCACHE_WD 106
`endif