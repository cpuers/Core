#ifndef TX_HPP
#define TX_HPP

#include <common.hpp>
#include <array>

class Tx {
public:
    u64     st;
    u64     ed;

    Tx();
    virtual ~Tx();

    virtual bool done();
};

class ICacheTx : public Tx {
public:
    u32     araddr;
    bool    uncached;
    std::array<u32, 4> rdata;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;

    ICacheTx();
    virtual ~ICacheTx();
};

class ICacheTxR: public ICacheTx {
public:
    ICacheTxR(u32 araddr);
    virtual ~ICacheTxR();
};

class DCacheTx : public Tx {
public:
    bool    op;
    u32     addr;
    bool    uncached;
    u32     rdata;
    u8      awstrb;
    u32     wdata;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;

    DCacheTx();
    virtual ~DCacheTx();
};

class DCacheTxR : public DCacheTx {
public:
    DCacheTxR(u32 addr);
    virtual ~DCacheTxR();
};

class DCacheTxW: public DCacheTx {
public:
    DCacheTxW(u32 addr, u8 awstrb, u32 wdata);
    virtual ~DCacheTxW();
};

#endif
