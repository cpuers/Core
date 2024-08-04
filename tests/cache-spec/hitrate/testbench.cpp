#include <testbench.hpp>
#include <vector>
#include <unistd.h>

struct trace {
  uint32_t addr : 28;
  uint8_t len : 3;
  bool is_write : 1;
};

FILE *fp = NULL;

Testbench::Testbench(int argc, char** argv) {
    fp = popen("bzcat microbench-test.log.bz2", "r");
    assert(fp);
}

Testbench::~Testbench() {
    pclose(fp);
}

static u8 len2strb(u32 addr, u8 len) {
    // if (len != 1 && len != 2 && len != 4) {
    //     int c = rand();
    //     switch (addr & 0x3) {
    //         case 0: {
    //             switch (c % 3) {
    //                 case 0: len = 1; break;
    //                 case 1: len = 2; break;
    //                 case 2: len = 4; break;
    //             }
    //         } break;
    //         case 1: case 3: {
    //             len = 1;
    //         } break;
    //         case 2: {
    //             len = (c & 1) ? 1 : 2;
    //         }
    //     }
    // }
    u8 strb = 0;
    for (int i = 0; i < len; i ++) {
        strb |= (1 << ((addr & 0x3) + i));
    }
    return strb;
}

std::vector<Tx *> Testbench::tests() {
    std::vector<Tx *> v;

    struct trace t;
    while (fread(&t, sizeof(t), 1, fp) == 1) {
        t.addr &= ~((u32)t.len - 1);
        if (t.is_write) {
            v.push_back(new DCacheTxW(t.addr, len2strb(t.addr, t.len), rand()));
        } else {
            v.push_back(new DCacheTxR(t.addr, len2strb(t.addr, t.len)));
        }
    }

    return v;
}
