
`define BPU_SIZE 512
`define RAS_SIZE 8

`define BPU_PC 31:2

//`define BPU_LINE_GROUP 3:2
`define BPU_LINE_IDX 10:2
`define BPU_LINE_TAG 29:11

`define BPU_IDX_SZIE 9
`define BPU_TAG_SIZE 19
`define RAS_IDX_SIZE 3

`define PHT_LINE_SIZE 2
`define BTB_LINE_SIZE 51  //type2, tag19, target30
`define BTB_TYPE 50:49
`define BTB_TAG 48:30
`define BTB_TARGET 29:0

`define RAS_LINE_SIZE 30

`define QUEUE_LINE_SIZE 30
`define QUEUE_SZIE 16
`define QUEUE_IDX_SZIE 4