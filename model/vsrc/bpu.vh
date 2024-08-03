
`define PHT_SIZE 64
`define BTB_SIZE 64

`define RAS_SIZE 8
`define RAS_IDX_SIZE 3

`define BPU_PC 31:2

//`define BPU_LINE_GROUP 3:2
`define BPU_LINE_IDX 7:2
`define BPU_LINE_TAG1 19:8
`define BPU_LINE_TAG2 31:20

`define BPU_LINE_TAG3 31:22
`define BPU_LINE_TAG4 25:20
`define BPU_LINE_TAG5 31:26


`define BTB_TYPE 43:42
`define BTB_TAG 41:30
`define BTB_TARGET 29:0
`define BTB_LINE_SIZE 44  //type2, tag12, target30

`define BTB_IDX_SIZE 6
`define BTB_TAG_SIZE 12

`define PHT_LINE_SIZE 2

`define RAS_LINE_SIZE 30

`define QUEUE_LINE_SIZE 30
`define QUEUE_SIZE 16
`define QUEUE_IDX_SIZE 4

`define GHR_SIZE 4