#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

// framework bug
// std::vector<Tx *> Testbench::tests() {
//     std::vector<Tx *> v;
//     v.push_back(new ICacheTxR(0x10));
//     for (int i = 0; i < 4; i ++) {
//         v.push_back(new ICacheTxRH(0x10));
//     }
//     v.push_back(new ICacheTxR(0x10010));
//     for (int i = 0; i < 4; i ++) {
//         v.push_back(new ICacheTxRH(0x10010));
//     }
//     v.push_back(new ICacheTxRH(0x10));
//     v.push_back(new ICacheTxRH(0x10010));
//     v.push_back(new ICacheTxR(0x20010));
//     v.push_back(new ICacheTxR(0x30010));
//     v.push_back(new ICacheTxR(0x10));
//     for (int i = 0; i < 65536; i ++) {
//         int c = rand() % 4;
//         switch (c) {
//         case 0: {
//             v.push_back(new ICacheTxR(rand() % 4096 + i));
//         } break;
//         case 1: {
//             v.push_back(new DCacheTxR(rand()));
//         } break;
//         case 2: {
//             v.push_back(new DCacheTxW(rand(), 0xff, rand()));
//         } break;
//         }
//     }
//     return v;
// }

// framework bug: SRAM WR at same time 235743 (s)
// std::vector<Tx *> Testbench::tests() {
//     std::vector<Tx *> v;
//     v.push_back(new ICacheTxR(0x10));
//     for (int i = 0; i < 4; i ++) {
//         v.push_back(new ICacheTxRH(0x10));
//     }
//     v.push_back(new ICacheTxR(0x10010));
//     for (int i = 0; i < 4; i ++) {
//         v.push_back(new ICacheTxRH(0x10010));
//     }
//     v.push_back(new ICacheTxRH(0x10));
//     v.push_back(new ICacheTxRH(0x10010));
//     v.push_back(new ICacheTxR(0x20010));
//     v.push_back(new ICacheTxR(0x30010));
//     v.push_back(new ICacheTxR(0x10));
//     for (int i = 0; i < 65536; i ++) {
//         int c = rand() % 4;
//         switch (c) {
//         case 0: {
//             v.push_back(new ICacheTxR(rand() % 4096 + i * 16));
//         } break;
//         case 1: {
//             v.push_back(new DCacheTxR(rand() % 8192 + i * 8));
//         } break;
//         case 2: {
//             v.push_back(new DCacheTxW(rand(), 0xff, rand()));
//         } break;
//         }
//     }
//     return v;
// }

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;
    v.push_back(new ICacheTxR(0x10));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxRH(0x10));
    }
    v.push_back(new ICacheTxR(0x10010));
    for (int i = 0; i < 4; i ++) {
        v.push_back(new ICacheTxRH(0x10010));
    }
    v.push_back(new ICacheTxRH(0x10));
    v.push_back(new ICacheTxRH(0x10010));
    v.push_back(new ICacheTxR(0x20010));
    v.push_back(new ICacheTxR(0x30010));
    v.push_back(new ICacheTxR(0x10));
    for (int i = 0; i < 8192; i ++) {
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
