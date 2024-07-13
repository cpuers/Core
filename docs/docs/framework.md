
# 测试框架

## 设计思路

由于需要对各个部件分别写单元测试；不同类型的部件的单元测试形态差别大。所以需要写出多个种类的测试框架，让每个单元测试单独选择顶层模块和测试框架。

- 在 `tests` 中，每一个目录对应一个单元测试；

- 在 `framework` 中，每一个目录对应一种测试框架，单元测试可以选择不同的测试框架；

- 在 `model` 中，`Makefile` 能够根据单元测试选择的顶层模块生成 Verilator 模型（静态链接库）；

三个部分通过静态库的形式链接起来生成可执行文件；

## 目录结构

```
.
├── framework               # Frameworks
│   ├── common              # common files for frameworks
│   ├── nvboard             # testing using NVBoard
│   └── simple-timing       # 
│       ├── framework.cpp
│       └── testbench.hpp
├── model                   # Design of CPU Core
│   ├── Makefile
│   └── vsrc                # Put verilog files here
│       ├── adder.v
│       └── regfile.v
└── tests                   # Unit tests
    ├── adder-spec
    │   ├── adder-spec.gtkw
    │   ├── main.cpp
    │   └── Makefile        # specify `TOP`, `FW`, ... here
    ├── regfile-spec
    │   ├── Makefile
    │   ├── regfile-spec.gtkw
    │   └── tb.cpp
    └── tests.mk
```

## 一个单元测试的构成

一个单元测试是一个 C++ 程序加上它的 `Makefile`；其中，`Makefile` 起到了配置文件的作用。下面将分析 `adder-spec` 和 `regfile-spec` 的 `Makefile`，介绍一个单元测试的构成；

```make
# adder-spec/Makefile
NAME = adder-spec   # the name of unit test
TOP  = adder        # dut's top module
SRCS = main.cpp     # list of C++ source files,
                    # relative to `adder-spec`
                    # (unit test root directory)
# INC_PATH += .     # extra include pathes

include ../tests.mk # common rules for unit tests
```

`NAME` 和 `TOP` 被转换成了 C++ 宏，`NAME` -> `TEST`，`TOP` -> `VTOP`。可以参照 `adder-spec/main.cpp` 理解；

```cpp
#include <VTOP.h> // hack, symbolic link to V[top].h

    // marco `VTOP` refers to [top]'s C++ type (Vadder)
    VTOP*             dut  = new VTOP;

    // marco `TEST` refers to unit test's name (adder-spec)
    fstp->open("build/" TEST ".fst");
```

单元测试可以在 `Makefile` 中设置 `FW` 变量来选择框架，或者留空不选择任何框架。选中的框架代码将会和单元测试代码混合起来编译。

## 可用的框架

### common

包含了 NEMU 中的常用宏和日志功能；需要自己编写 `main` 函数等；

### simple-timing

用户只需提供 `Testbench` 类的实现。`Testbench` 只能根据框架给出的时间设置输入和检查输出；

### nvboard (WIP)

接入 NVBoard，可以以图形化方式，手动测试一些简单电路；

## `.gitignore` 的设置

1. `tests/*/$(NAME).gtkw` GTKWave 配置文件

    默认不加入版本控制，因为其中内容随着 GTKWave 启动而变化，但如果某人提供了较好的初始配置，可以用 `-f` 强制加入；

## FAQ

1. 如何初始化环境，配置代码补全？

    > ```sh
    > $ pwd
    > /path/to/Core
    > $ source .corerc
    > ```

1. 在编写测试的时候因为硬件模型还没有生成，`VTOP.h` 不存在，没有代码补全，如何处理？

    > 在 `model` 路径下手动执行 
    > ```sh
    > $ make TOP=[top]
    > $ ln -sfn -T V[top].h build/[top]/VTOP.h
    > ```
