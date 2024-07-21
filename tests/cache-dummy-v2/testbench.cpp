#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    for (int i = 0; i < 100; i ++) {
        // if (rand() & 1) {
        //    v.push_back(new ICacheTxR(rand()));
        // } else {
             v.push_back(new DCacheTxR(rand()));
        // }
    }
    return v;
}
