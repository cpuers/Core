#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}


std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    v.push_back(new DCacheTxR(0x8010, DCacheTx::rand_strb(0x8010)));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new DCacheTxRH(0x8010, DCacheTx::rand_strb(0x8010)));
        v.push_back(new DCacheTxWH(0x8010, 0xf, rand()));
    }
    v.push_back(new DCacheTxR(0x9010, DCacheTx::rand_strb(0x9010)));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new DCacheTxWH(0x9010, 0xf, rand()));
        v.push_back(new DCacheTxRH(0x9010, DCacheTx::rand_strb(0x9010)));
    }
    v.push_back(new DCacheTxRH(0x8010, DCacheTx::rand_strb(0x8010)));
    v.push_back(new DCacheTxRH(0x9010, DCacheTx::rand_strb(0x9010)));
    v.push_back(new DCacheTxR(0xa010, DCacheTx::rand_strb(0xa010)));
    v.push_back(new DCacheTxR(0xb010, DCacheTx::rand_strb(0xb010)));
    v.push_back(new DCacheTxR(0x8010, DCacheTx::rand_strb(0x8010)));
    v.push_back(new TxClear);
    u32 addr;
    for (int i = 0; i < 512; i ++) {
        if (rand() & 1) {
            v.push_back(new DCacheTxR(i * 4, DCacheTx::rand_strb(i*4)));
        } else {
            addr = i * 4 + (rand() % 32 - 8);
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
        }
    }
    for (int i = 0; i < 16384; i ++) {
        int c = rand() % 4;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            addr = rand() % 8192 + i * 4;
            v.push_back(new DCacheTxR(addr, DCacheTx::rand_strb(addr)));
        } break;
        case 2: {
            addr = rand() % 8192 + i * 4;
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
        } break;
        }
    }
    v.push_back(new TxClear);
    for (int i = 0; i < 16384; i ++) {
        int c = rand() % 3;
        u32 addr;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            addr = rand() % 8192 + i * 4;
            v.push_back(new DCacheTxR(addr, DCacheTx::rand_strb(addr)));
        } break;
        case 2: {
            addr = rand() % 8192 + i * 4;
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
        } break;
        }
    }
    for (int i = 0; i < 10000; i ++) {
        int c = rand() % 3;
        u32 addr = rand() % 8192 - 4096 + UNCACHED_SIZE;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(addr));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(addr, DCacheTx::rand_strb(addr)));
        } break;
        case 2: {
            addr = rand() % 8192 - 4096 + UNCACHED_SIZE;
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
        } break;
        }
    }
    return v;
}
