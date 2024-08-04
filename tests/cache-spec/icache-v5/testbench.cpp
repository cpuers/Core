#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    v.push_back(new ICacheTxR(0x8010));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxRH(0x8010));
    }
    v.push_back(new ICacheTxR(0x10010));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxRH(0x10010));
    }
    v.push_back(new ICacheTxRH(0x8010));
    v.push_back(new ICacheTxRH(0x10010));
    v.push_back(new ICacheTxR(0x20010));
    v.push_back(new ICacheTxR(0x30010));
    v.push_back(new ICacheTxR(0x8010));
    u32 addr;
    for (int i = 0; i < 65536; i ++) {
        int c = rand() % 4;
        addr = rand() % 8192 + i * 4;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(addr, DCacheTx::rand_strb(addr)));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
        } break;
        }
    }
    return v;
}
