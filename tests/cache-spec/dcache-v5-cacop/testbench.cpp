#include <testbench.hpp>
#include <stdlib.h>

Testbench::Testbench(int, char**) {}
Testbench::~Testbench() {}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;

    // DCache Init
    {
        for (u8 way = 0; way < 4; way ++) {
            for (u16 idx = 0; idx < 256; idx ++) {
                v.push_back(new DCacheTxCINV(way, idx));
            }
        }
    }
    v.push_back(new TxClear);

    // DCache CLOOKUP
    {
        v.push_back(new DCacheTxR(0x8000, DCacheTx::rand_strb(0x8000)));
        v.push_back(new DCacheTxFlushRW);

        v.push_back(new DCacheTxCLOOKUP(0x8000));
        v.push_back(new DCacheTxW(0x8000, DCacheTx::rand_strb(0x8000), rand()));
        v.push_back(new DCacheTxFlushRW);

        v.push_back(new DCacheTxCLOOKUP(0x8000));

        v.push_back(new DCacheTxR(0x8000, DCacheTx::rand_strb(0x8000)));
        v.push_back(new DCacheTxFlushRW);
        v.push_back(new DCacheTxR(0x8000, DCacheTx::rand_strb(0x8000)));
        v.push_back(new DCacheTxCLOOKUP(0x8000));

        v.push_back(new TxClear);

        v.push_back(new DCacheTxW(0x8010, DCacheTx::rand_strb(0x8010), rand()));
        v.push_back(new DCacheTxW(0x8010, DCacheTx::rand_strb(0x8010), rand()));
        v.push_back(new DCacheTxW(0x8010, DCacheTx::rand_strb(0x8010), rand()));
        v.push_back(new DCacheTxFlushRW);
        v.push_back(new DCacheTxCLOOKUP(0x8010));
        v.push_back(new DCacheTxR(0x8010, DCacheTx::rand_strb(0x8010)));
    }
    v.push_back(new TxClear);

    // DCache CIDX
    {
        std::vector<u32> addrs;
        for (int i = 0; i < 1000; i ++) {
            u32 addr = rand();
            v.push_back(new DCacheTxW(addr, DCacheTx::rand_strb(addr), rand()));
            addrs.push_back(addr);
        }
        v.push_back(new DCacheTxFlushRW);

        for (int i = 0; i < 100; i ++) {
            u8 way = rand() % 4;
            u16 idx = rand() % 256;
            v.push_back(new DCacheTxCIDX(way, idx));
        }

        for (auto addr: addrs) {
            v.push_back(new DCacheTxR(addr, DCacheTx::rand_strb(addr)));
        }
    }
    v.push_back(new TxClear);

    // Full random test
    {
        std::queue<u32> written;
        std::queue<u32> flushed;
        for (int i = 0; i < 262144; i ++) {
            Tx *tx = nullptr;
            int op = rand() % 8;
            int c = rand() % 8;
            u32 off = rand() % 4096;
            u32 addr = 0x8000 + c * 0x1000 + off * 4 + i;
            u8 strb = DCacheTx::rand_strb(addr);
            u8 way;
            u16 idx;
            switch (op) {
            case 0: {
                tx = new ICacheTxR(addr);
            } break;
            case 6: {
                if (!written.empty()) {
                    addr = written.front();
                    strb = DCacheTx::rand_strb(addr);
                    written.pop();
                }
                tx = new DCacheTxR(addr, strb);
            } break;
            case 7: {
                if (!flushed.empty()) {
                    addr = flushed.front();
                    strb = DCacheTx::rand_strb(addr);
                    flushed.pop();
                }
                tx = new DCacheTxR(addr, strb);
            } break;
            case 1: {
                tx = new DCacheTxR(addr, strb);
            } break;
            case 2: {
                tx = new DCacheTxW(addr, strb, rand());
                written.push(addr);
            } break;
            case 3: {
                tx = new DCacheTxCLOOKUP(addr);
                flushed.push(addr);
            } break;
            case 4: {
                way = rand() % 4;
                idx = rand() % 256;
                tx = new DCacheTxCIDX(way, idx);
            } break;
            case 5: {
                tx = new DCacheTxFlushRW;
            } break;
            }
            assert(tx);
            v.push_back(tx);
        }
    }

    return v;
}
