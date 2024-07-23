#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    // Check icache_dummy_v2 can accept request in state_receive
    for (int i = 0; i < 20; i ++) {
        v.push_back(new ICacheTxR(32));
    }
    v.push_back(new TxClear);
    // Check dcache_dummy_v2 can accept request in state_receive
    for (int i = 0; i < 20; i ++) {
        v.push_back(new DCacheTxR(32));
    }
    v.push_back(new TxClear);
    // Random test, check correctness
    for (int i = 0; i < 65536; i ++) {
        int c = rand() % 3;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR(rand()));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(rand()));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(rand(), 0xff, rand()));
        } break;
        }
    }
    return v;
}
