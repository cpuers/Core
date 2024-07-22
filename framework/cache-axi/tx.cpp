#include <tx.hpp>

Tx::Tx() : st(0), ed(0) {}

ICacheTx::ICacheTx() {
    araddr = 0;
    uncached = false;
    rdata = {0, 0, 0, 0};
    cacop_en = false;
    cacop_code = 0;
    cacop_addr = 0;
}
ICacheTxR::ICacheTxR(u32 araddr) { 
    this->araddr = araddr; 
}
DCacheTx::DCacheTx() {
    op = false;
    addr = 0;
    uncached = false;
    rdata = 0;
    awstrb = 0;
    wdata = 0;
    cacop_en = false;
    cacop_code = 0;
    cacop_addr = 0;
}
DCacheTxR::DCacheTxR(u32 addr) { 
    this->addr = addr; 
}
DCacheTxW::DCacheTxW(u32 addr, u8 awstrb, u32 wdata) {
    this->op = true;
    this->addr = addr;
    this->awstrb = awstrb;
    this->wdata = wdata;
}
bool Tx::done() { return true; }
Tx::~Tx() {}
bool CacheTx::hit() { return ed - st <= 4; }
