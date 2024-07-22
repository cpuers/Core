#ifndef RAM_HPP
#define RAM_HPP

#include <common.hpp>
#include <array>

#define MEM_SIZE 65536 // bytes

class Ram {
private:
    u32 imem[MEM_SIZE/4];
    u32 dmem[MEM_SIZE/4];
public:
    Ram();
    ~Ram();
    std::array<u32, 4> iread(u32 addr, bool uncached);
    u32 dread(u32 addr, bool uncached);
    void dwrite(u32 addr, u32 data, u8 wstrb, bool uncached);
};

#endif
