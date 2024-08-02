#ifndef RAM_HPP
#define RAM_HPP

#include <common.hpp>
#include <cache.hpp>
#include <array>
#include <queue>

#define MEM_SIZE 4 * 1024 * 1024 // bytes
#define UNCACHED_SIZE 32768 // bytes
static_assert((MEM_SIZE & (MEM_SIZE - 1)) == 0, "MEM_SIZE must be power of 2.");
static_assert(((UNCACHED_SIZE & (UNCACHED_SIZE - 1)) == 0), "UNCACHED_SIZE must be power of 2.");

class Ram {
private:
    using Q = std::queue<u32>;
    Q m[MEM_SIZE / 4];
public:
    Ram();
    ~Ram();
    bool ircheck(u32 addr, ir_t rdata, set<ir_t> &s);
    bool drcheck(u32 addr, u8 strb, dr_t rdata, set<dr_t> &s);
    void dwrite(u32 addr, u8 strb, dw_t wdata);
};

#endif
