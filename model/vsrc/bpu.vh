
`define PHT_SIZE 128
`define BTB_SIZE 128

`define RAS_SIZE 8
`define RAS_IDX_SIZE 3

`define BPU_PC 31:2

//`define BPU_LINE_GROUP 3:2
`define BPU_LINE_IDX 8:2
`define BPU_LINE_TAG1 19:9
`define BPU_LINE_TAG2 30:20


`define BTB_TYPE 31:30
`define BTB_TAG 40:30
`define BTB_TARGET 29:0
`define BTB_LINE_SIZE 32  //type2, tag11, target30

`define BTB_IDX_SIZE 7
`define BTB_TAG_SIZE 11

`define PHT_LINE_SIZE 2

`define RAS_LINE_SIZE 30

`define QUEUE_LINE_SIZE 30
`define QUEUE_SIZE 16
`define QUEUE_IDX_SIZE 4

`define GHR_SIZE 4