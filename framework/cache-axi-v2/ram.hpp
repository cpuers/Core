#ifndef RAM_HPP
#define RAM_HPP

#include <common.hpp>
#include <cache.hpp>
#include <array>
#include <queue>

#define MEM_SIZE 65536 // bytes
static_assert((MEM_SIZE & (MEM_SIZE - 1)) == 0, "MEM_SIZE must be power of 2.");

class Ram {
private:
    using Q = std::queue<u32>;
    Q m[MEM_SIZE / 4];
public:
    Ram();
    ~Ram();
    bool ircheck(u32 addr, ir_t rdata, set<ir_t> &s);
    bool drcheck(u32 addr, dr_t rdata, set<dr_t> &s);
    void dwrite(u32 addr, u8 wstrb, dw_t wdata);
};

#endif
