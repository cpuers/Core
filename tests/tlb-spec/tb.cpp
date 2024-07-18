#include <common.hpp>
#include <iostream>
#include <testbench.hpp>
#include <Vregfile.h>

#include <map>

static std::map<u8, u32> mem;

Testbench::Testbench(int argc, char **argv) {
    srand(time(NULL));
    for (u8 i = 0; i < 32; i ++) {
        mem[i] = 0;
    }
}

Testbench::~Testbench() {}

u64 Testbench::reset(Vregfile *dut) {
    dut->wen1 = 1;
    dut->wdata1 = 0;

    for (u8 i = 1; i < 32; i ++) {
        dut->rd1 = i;
        dut->eval();        
    }

    dut->wen1 = 0;

    return 4;
}

bool Testbench::step(Vregfile *dut, u64 time) {
    dut->rd1 = rand() % 32;
    dut->rs1 = rand() % 32;
    dut->rs2 = rand() % 32;
    dut->wdata1 = rand();
    dut->wen1 = rand() & 1;

    if (dut->wen1) mem[dut->rd1] = dut->wdata1;
    mem[0] = 0;

    return time > 10000;
}

bool Testbench::check(Vregfile *dut, u64 time) {
    bool flag = true;
    flag &= dut->rs1data == mem[dut->rs1];
    if (!flag) {
        std::cerr << "Checking " << (int)dut->rs1
            << ", Expected " << mem[dut->rs1]
            << ", Result " << dut->rs1data << '\n';
        return flag;
    }
    flag &= dut->rs2data == mem[dut->rs2];
    if (!flag) {
        std::cerr << "Checking " << (int)dut->rs2
            << ", Expected " << mem[dut->rs2]
            << ", Result " << dut->rs2data << '\n';
    }
    static int tot = 0;
    if(flag) std::cout << "sample " << ++tot << "Pass\n";
    return flag;
}
