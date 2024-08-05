#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}


std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;

    v.push_back(new DCacheTxR(0x8000, 0xf));
    v.push_back(new DCacheTxRH(0x8000, 0xf));
    v.push_back(new DCacheTxR(0x9000, 0xf));
    v.push_back(new DCacheTxRH(0x8000, 0xf));
    v.push_back(new DCacheTxRH(0x9000, 0xf));
    v.push_back(new DCacheTxR(0xa000, 0xf));
    v.push_back(new DCacheTxRH(0x8000, 0xf));
    v.push_back(new DCacheTxRH(0x9000, 0xf));
    v.push_back(new DCacheTxRH(0xa000, 0xf));
    v.push_back(new DCacheTxR(0xb000, 0xf));
    v.push_back(new DCacheTxRH(0x8000, 0xf));
    v.push_back(new DCacheTxRH(0x9000, 0xf));
    v.push_back(new DCacheTxRH(0xa000, 0xf));
    v.push_back(new DCacheTxRH(0xb000, 0xf));
    v.push_back(new DCacheTxR(0xc000, 0xf));
    v.push_back(new DCacheTxRH(0x9000, 0xf));
    v.push_back(new DCacheTxRH(0xa000, 0xf));
    v.push_back(new DCacheTxRH(0xb000, 0xf));
    v.push_back(new DCacheTxR(0xc000, 0xf));
    v.push_back(new DCacheTxR(0xd000, 0xf));
    v.push_back(new DCacheTxR(0xe000, 0xf));
    v.push_back(new DCacheTxR(0xf000, 0xf));
    v.push_back(new TxClear);

    v.push_back(new DCacheTxW(0x8000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x8000, 0xf, rand()));
    v.push_back(new DCacheTxW(0x9000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x8000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x9000, 0xf, rand()));
    v.push_back(new DCacheTxW(0xa000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x8000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x9000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0xa000, 0xf, rand()));
    v.push_back(new DCacheTxW(0xb000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x8000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x9000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0xa000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0xb000, 0xf, rand()));
    v.push_back(new DCacheTxW(0xc000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0x9000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0xa000, 0xf, rand()));
    v.push_back(new DCacheTxWH(0xb000, 0xf, rand()));
    v.push_back(new TxClear);

    for (int i = 0; i < 1000; i ++) {
        v.push_back(new DCacheTxR(0x8600 + i*4, 0xf));
        v.push_back(new DCacheTxW(0x9600 + i*4, 0xf, rand()));
    }
    

    for (int i = 0; i < 1000; i ++) {
        v.push_back(new DCacheTxR(0xa600 + i*4, 0xf));
        v.push_back(new DCacheTxW(0xb600 + i*4, 0xf, rand()));
    }

    for (int i = 0; i < 1000; i ++) {
        v.push_back(new DCacheTxRH(0x8600 + i*4, 0xf));
        v.push_back(new DCacheTxWH(0x9600 + i*4, 0xf, rand()));
    }

    v.push_back(new TxClear);

    for (int i = 0; i < 16384; i ++) {
        int op = rand() % 2;
        int c = rand() % 8;
        u32 off = rand() % 4096;
        u32 addr = 0x8000 + c * 0x1000 + off * 4;
        if (op) {
            v.push_back(new DCacheTxR(addr, 0xf));
        } else {
            v.push_back(new DCacheTxW(addr, 0xf, rand()));
        }
    }
    
    return v;
}
