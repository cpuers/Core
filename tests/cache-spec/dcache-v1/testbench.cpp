#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    v.push_back(new DCacheTxR(0x10));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new DCacheTxRH(0x10));
        v.push_back(new DCacheTxWH(0x10, 0xff, rand()));
    }
    v.push_back(new DCacheTxW(0x10010, 0xff, rand()));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new DCacheTxWH(0x10010, 0xff, rand()));
        v.push_back(new DCacheTxRH(0x10010));
    }
    for (int i = 0; i < 512; i ++) {
        if (rand() & 1) {
            v.push_back(new DCacheTxR(i * 4));
        } else {
            v.push_back(new DCacheTxW(i * 4 + (rand() % 32 - 8), 0xff, rand()));
        }
    }
    // v.push_back(new DCacheTxRH(0x10));
    // v.push_back(new DCacheTxRH(0x10010));
    // v.push_back(new DCacheTxR(0x20010));
    // v.push_back(new DCacheTxR(0x30010));
    // v.push_back(new DCacheTxR(0x10));
    for (int i = 0; i < 65536; i ++) {
        int c = rand() % 4;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand() % 4096 + i * 4));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(rand() % 8192 + i * 4));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(rand() % 8192 + i * 4, 0xff, rand()));
        } break;
        }
    }
    return v;
}
