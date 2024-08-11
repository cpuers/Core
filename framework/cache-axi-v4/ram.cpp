#include <cache.hpp>
#include <common.hpp>
#include <cstdlib>
#include <ram.hpp>

static u32 *mem = nullptr;

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
    mem = (u32 *)malloc(MEM_SIZE);
    for (u32 i = 0; i < MEM_SIZE / 4; i ++) {
        m[i].push(i);
        mem[i] = i;
    }
}
Ram::~Ram() {
}

bool Ram::ircheck(u32 addr, ir_t rdata, set<ir_t>& s) {
    u32 a = (addr / 16) * 4 % (MEM_SIZE / 4);
    set<u32> k[4];
    bool flag = true;
    for (int i = 0; i < 4; i ++) {
        while (m[a+i].size() > 1) {
            if (m[a+i].front() != rdata[i]) {
                k[i].insert(m[a+i].front());
                m[a+i].pop();
            } else {
                k[i].insert(m[a+i].front());
                break;
            }
        }
        if (m[a+i].front() != rdata[i]) {
            flag = false;
            k[i].insert(m[a+i].front());
        } else {
            k[i].insert(m[a+i].front());
        }
    }
    if (!flag) {
        for (auto a: k[0]) {
            for (auto b: k[1]) {
                for (auto c: k[2]) {
                    for (auto d: k[3]) {
                        s.insert({a, b, c, d});
                    }
                }
            }
        }
        return false;
    }
    return true;
}

bool Ram::drcheck(u32 addr, u8 strb, dr_t rdata, set<dr_t> &s) {
    u32 a = (addr / 4) % (MEM_SIZE / 4);
    dr_t mask = 0;
    for (int i = 0; i < 4; i ++) {
        if (strb & (1U << i)) {
            mask |= (0xffUL << (i*8));
        }
    }
    if ((m[a].back() & mask) != (rdata & mask)) {
        s.insert(m[a].back());
        return false;
    }
    return true;
}

void Ram::dwrite(u32 addr, u8 strb, dw_t wdata) {
    u32 a = (addr / 4) % (MEM_SIZE / 4);
    u32 o;
    o = m[a].back();
    u32 t = 0;
    for (int i = 0; i < 4; i ++) {
        if (strb & (1U << i)) {
            t |= (wdata & (0xffUL << (i * 8)));
        } else {
            t |= (o & (0xffUL << (i * 8)));
        }
    }
    if (o != t) {
        m[a].push(t);
#ifndef CACHE_ALL
        if (addr < UNCACHED_SIZE) {
            while (m[a].size() > 2) m[a].pop();
        }
#endif
    }

}
