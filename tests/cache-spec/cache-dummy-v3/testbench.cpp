#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

static u8 rand_strb() {
    switch (rand() % 3) {
    case 0: return 0xf;
    case 1: return 0x1;
    case 2: return 0x3;
    default: assert(false);
    }
}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    for (int i = 0; i < 512; i ++) {
        if (rand() & 1) {
            v.push_back(new DCacheTxR(i * 4, rand_strb()));
        } else {
            v.push_back(new DCacheTxW(i * 4 + (rand() % 32 - 8), 0xf, rand()));
        }
    }
    for (int i = 0; i < 16384; i ++) {
        int c = rand() % 4;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(rand() % 8192 + i * 4, rand_strb()));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(rand() % 8192 + i * 4, 0xf, rand()));
        } break;
        }
    }
    // v.push_back(new TxClear);
    for (int i = 0; i < 16384; i ++) {
        int c = rand() % 4;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(rand() % 8192 + i * 4, rand_strb()));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(rand() % 8192 + i * 4, rand_strb(), rand()));
        } break;
        }
    }
    return v;
}
