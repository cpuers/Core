#ifndef TX_HPP
#define TX_HPP

#include <common.hpp>
#include <array>

class Tx {
protected:
    Tx();
public:
    u64     st;
    u64     ed;

    virtual ~Tx();
    virtual bool done();
};

class TxClear : public Tx {
};

class CacheTx : public Tx {
public:
    bool    uncached;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;
    virtual bool hit();
};

class ICacheTx : public CacheTx {
public:
    u32     araddr;
    std::array<u32, 4> rdata;

    ICacheTx();
};

class ICacheTxR: public ICacheTx {
public:
    ICacheTxR(u32 araddr);
};

class ICacheTxUR: public ICacheTx {
public:
    ICacheTxUR(u32 araddr);
};

class DCacheTx : public CacheTx {
public:
    bool    op;
    u32     addr;
    bool    uncached;
    u32     rdata;
    u8      awstrb;
    u32     wdata;

    DCacheTx();
};

class DCacheTxR : public DCacheTx {
public:
    DCacheTxR(u32 addr);
};

class DCacheTxW: public DCacheTx {
public:
    DCacheTxW(u32 addr, u8 awstrb, u32 wdata);
};

#endif
