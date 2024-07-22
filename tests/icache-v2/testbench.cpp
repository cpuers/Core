#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxR(36));
    }
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxR(75));
    }
    for (int i = 0; i < 65536; i ++) {
        int c = rand() % 3;
        switch (c) {
        case 0: {
            v.push_back(new ICacheTxR((i * 16) % 8192 + rand() % 128));
        } break;
        case 1: {
            v.push_back(new DCacheTxR(rand()));
        } break;
        case 2: {
            v.push_back(new DCacheTxW(rand(), 0xff, rand()));
        } break;
        }
        // v.push_back(new ICacheTxR(rand()));
    }
    return v;
}
