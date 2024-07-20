#include <array>
#include <common.hpp>
#include <cstdlib>
#include <ram.hpp>

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
            t |= (data & (0xffUL << i));
        } else {
            t |= (o & (0xffUL << i));
        }
    }
    mem[addr % (MEM_SIZE / 4)] = t;
}

Ram::Ram() {}
Ram::~Ram() {}
void Ram::init() {
    for (u32 i = 0; i < MEM_SIZE / 4; i ++) {
        mem[i] = rand();
        imem[i] = dmem[i] = mem[i];
    }
}
std::array<u32, 4> Ram::iread(u32 addr) {
    u32 a = (addr / 4) % (MEM_SIZE / 4);
    return {imem[a], imem[a + 1], imem[a + 2], imem[a + 3]};
}
u32 Ram::dread(u32 addr) {
    u32 valid_addr = (addr / 4) % (MEM_SIZE / 4);
    return dmem[valid_addr];
}
void Ram::dwrite(u32 addr, u32 data, u8 wstrb) {
    u32 valid_addr = (addr / 4) % (MEM_SIZE / 4);

    u32 o = dmem[valid_addr];
    u32 t = 0;
    for (int i = 0; i < 4; i ++) {
        if (wstrb & (1U << i)) {
            t |= (data & (0xffUL << i));
        } else {
            t |= (o & (0xffUL << i));
        }
    }
    dmem[valid_addr] = t;
}
