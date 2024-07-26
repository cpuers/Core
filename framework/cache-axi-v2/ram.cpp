#include <array>
#include <common.hpp>
#include <cstdlib>
#include <ram.hpp>
#include <cassert>
#include <cstring>

static u32 mem[MEM_SIZE / 4];

extern "C" 
void pmem_read(const u32 addr, u32 *rdata) {
    *rdata = mem[addr % (MEM_SIZE / 4)];
}

extern "C"
void pmem_write(const u32 addr, const u32 data, const u8 wstrb) {
    u32 o = mem[addr % (MEM_SIZE / 4)];
    u32 t = 0;
    for (int i = 0; i < 4; i ++) {
        if (wstrb & (1U << i)) {
            t |= (data & (0xffUL << (i * 8)));
        } else {
            t |= (o & (0xffUL << (i * 8)));
        }
    }
    mem[addr % (MEM_SIZE / 4)] = t;
}

Ram::Ram() {
    for (u32 i = 0; i < MEM_SIZE / 4; i ++) {
        mem[i] = i;
        imem[i] = dmem[i] = mem[i];
    }
}
Ram::~Ram() {}
std::array<u32, 4> Ram::iread(u32 addr, bool uncached) {
    u32 *m = uncached ? dmem : imem;
    u32 a = (addr / 16) * 4 % (MEM_SIZE / 4);
    return {m[a], m[a+1], m[a+2], m[a+3]};
}
u32 Ram::dread(u32 addr, bool uncached) {
    u32 *m = uncached ? mem : dmem;
    u32 valid_addr = (addr / 4) % (MEM_SIZE / 4);
    return m[valid_addr];
}
void Ram::dwrite(u32 addr, u32 data, u8 wstrb) {
    u32 *m = dmem;
    u32 valid_addr = (addr / 4) % (MEM_SIZE / 4);

    u32 o = m[valid_addr];
    u32 t = 0;
    for (int i = 0; i < 4; i ++) {
        if (wstrb & (1U << i)) {
            t |= (data & (0xffUL << (i * 8)));
        } else {
            t |= (o & (0xffUL << (i * 8)));
        }
    }
    m[valid_addr] = t;
}
void Ram::iflush(u32 addr) {
  u32 a = (addr / 16) * 4 % (MEM_SIZE / 4);
  for (int i = 0; i < 4; i++) {
    imem[a + i] = mem[a + i];
  }
}
