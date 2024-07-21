#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
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
