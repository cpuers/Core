# CPU

## 概述

## 各阶段概述

### if0阶段

- 将取指分为两个阶段，第一阶段负责计算next_pc并将其发往Icache,TLB等部件，其中更新规则及优先级如下	:

    1. 复位，PC 更新为入口地址 0xbfc00000。
    2. 分支预测失败，PC 更新为实际的跳转地址。
    3. icache 或下一级流水线繁忙, 此时保持PC不变
    4. 其他情况, 此时PC = PC & SEXT(0xf0) + 16

- 其接口主要如下:

    | Input/Output | 名称        | 作用                                                     |
    | ------------ | ----------- | -------------------------------------------------------- |
    | I            | clk         | 时钟信号                                                 |
    | I            | Flush_IF    | 冲刷流水线,高电平有效                                    |
    | I            | rst         | 复位信号                                                 |
    | I            | need_jump   | 表示分支预测失败需要跳转,高电平有效                      |
    | I            | jump_pc     | 跳转目标                                                 |
    | O            | valid       | 表示IF0段数据是否有效,高电平有效                         |
    | O            | iaddr       | 当前PC值                                                 |
    | O            | uncached    | 目前未实现,恒为0                                         |
    | I            | addr_ok     | Icache 握手信号                                          |
    | O            | if0_if1_bus | if0至if1间的总线                                         |
    | I            | IF_ready    | 与IF1的握手信号,为1表示if1空闲                           |
    | I            | pc_valid    | 由BPU给出, 表示每条指令是否有效,当前由于BPU未实现, 均为1 |
    | I            | pc_is_jump  | 每条指令是否发生跳转                                     |
    | I            | pre_next_pc | 分支预测给出的下条指令地址                               |

### if1阶段

- 此阶段负责接受从ICache传回的指令并将其放入InstrBuffer中, 其内置了一个4条指令大小的缓冲区(以下称为buffer), if1 阶段繁忙当且仅当该缓冲区内有指令, 这一阶段的状态描述大概如下

    ```
    if buffer.empty:
    	if if0 送入的指令数 > InsterBuffer.size:
    		直接将指令送入 InstrBuffer
    	else:
    		将指令暂存至buffer
    		buffer.empty = false
    else;
    	if buffer.size > InsterBuffer.size:
    		阻塞
    	else :
    		将buffer的所有指令送往Instrbuffer
    		buffer.empty = true
    ```

- 其主要接口如下:

- | Input/Output | 名称          | 作用                                             |
    | ------------ | ------------- | ------------------------------------------------ |
    | I            | clk           | 时钟信号                                         |
    | I            | Flush_IF      | 冲刷流水线,高电平有效                            |
    | I            | rst           | 复位信号                                         |
    | I            | if0_if1_bus   | if0至if1间的总线                                 |
    | O            | if1_to_ib     | if1传向 InstrBuffer的数据                        |
    | I            | can_push_size | InstrBuffer当前能够容纳的指令条数                |
    | I            | push_num      | 向InstrBuffer传入的指令条数,取值范围0~4          |
    | I            | data_ok       | Icache握手信号,表示数据是否已经准备好,高电平有效 |
    | I            | rdata         | Icache传来的数据                                 |
    | I            | if0_valid     | 表示if0传来的数据是否有效                        |
    | O            | IF_ready      | 与IF0的握手信号,为1表示if1空闲                   |

#### InstrBuffer

- InstBuffer 为一个FIFO, 其一次最多可以PUSH 4条指令, 可以POP 2两条指令, 通过InstBuffer, 取指和译码执行阶段进行了完全分离, 只要 InstBuffer 不为空, 译码执行阶段都可以正常进行, 同理, 取指阶段做的也只有取指令并更新PC, 无需在意后续流水线是否被阻塞.

### id阶段

- 此阶段由两个子译码器和一个发射判断器件组成, 其负责向产生译码信号, 并判断是否需要退化成单发射, 目前需要退化成单发射的情况如下:

    - 第一条指令是跳转指令

    - 第一条指令和第二条指令发生RAW冒险

    - 第一条指令和第二条指令均为访存指令

- 其主要接口如下:

    | Input/Output | 名称               | 作用                                            |
    | ------------ | ------------------ | ----------------------------------------------- |
    | I            | clk                | 时钟信号                                        |
    | I            | Flush_ID           | 冲刷流水线,高电平有效                           |
    | I            | rst                | 复位信号                                        |
    | I            | IF_instr0/1        | 从InstrBuffer中读取的数据                       |
    | O            | IF_pop_op          | 从InstrBuffer中Pop的指令数量                    |
    | O            | EXE_instr0/1       | 向EXE阶段传递的译码数据                         |
    | O            | EXE_instr0/1_valid | 表示向EXE阶段传递的数据是否有效,高电平有效      |
    | I            | EXE_ready          | EXE阶段握手信号, 表示EXE阶段是否空闲,高电平有效 |
    | O            | read_addr0~3       | 读取寄存器的地址                                |
    | I            | readdata0~3        | 从寄存器读出的数据                              |

### exm阶段
- 此阶段整合了EXE阶段和MEM阶段，通过对指令的判断选择相应的执行部件fu结果:
    - alu:进行一般算术和逻辑运算
  
    - agu:用于访问内存（通过cache）
  
    - branchcond:进行跳转处理，判断分支预测是否正确，处理分支预测错误的情况
  
    - 乘除法器:进行乘除法运算
  
- 其主要接口如下:

    | Input/Output | 名称               | 作用                                            |
    | ------------ | ------------------ | ----------------------------------------------- |
    | I            | clk                | 时钟信号                                        |
    | I            | reset              | 复位信号                                        |
    | I            | ws_allowin         | WB阶段握手信号，表示WB阶段是否空闲，高电平有效      |
    | O            | es_allowin         | EXM阶段握手信号, 表示EXE阶段是否空闲,高电平有效     |
    | I            | ds_to_es_valid     | ID向EXM阶段传递的数据是否有效,高电平有效            |
    | I            | ds_to_es_bus       | ID向EXM阶段传递的指令数据                         |
    | I            | forward_data1      | 第一条EXM段流水线的旁路信息                       |
    | I            | forward_data2      | 第二条EXM段流水线的旁路信息                       |
    | O            | exm_forward_bus    | 该流水线的给下一周期指令的旁路信息                 |
    | O            | br_bus             | 分支预测失败的前转的正确跳转信息                   |
    | O            | flush_IF           | 冲刷IF流水线段，高电平有效                        |
    | O            | flush_ID           | 冲刷ID流水线段，高电平有效                        |
    | O            | es_to_ws_valid     | EXM向WB阶段传递的数据是否有效,高电平有效           |
    | O            | es_to_ws_bus       | EXM向WB阶段传递的指令数据                        |
    | I            | dcache_rdata_bus   | dcache中读取的信息                               |
    | O            | dcache_wdata_bus   | 写入dcache的信息                                 |

### wb阶段
- 此阶段进行计算结果到寄存器的写入

- 其主要接口如下:

    | Input/Output | 名称               | 作用                                            |
    | ------------ | ------------------ | ----------------------------------------------- |
    | I            | clk                | 时钟信号                                        |
    | I            | reset              | 复位信号                                        |
    | O            | ws_allowin         | WB阶段握手信号，表示WB阶段是否空闲，高电平有效      |
    | I            | es_to_ws_valid1    |第一条EXM段传递的数据是否有效,高电平有效            |
    | I            | es_to_ws_valid2    | 第一条EXM段传递的数据是否有效,高电平有效           |
    | I            | es_to_ws_bus1      | 第一条EXM段传递的数据                            |
    | I            | es_to_ws_bus2      | 第二条EXM段传递的数据                            |
    | O            | ws_to_rf_bus       | 写入寄存器的信息                                 |

