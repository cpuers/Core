#ifndef TX_HPP
#define TX_HPP

#include <common.hpp>
#include <array>
#include <VTOP.h>
#include <ram.hpp>

class Tx {
public:
    enum class State {
        PENDING, STARTED, ENDED
    };

    void st(u64 t);
    void ed(u64 t);
    u64 st();
    u64 ed();

    virtual ~Tx();
    State state();

  protected:
    u64     st_;
    u64     ed_;

    State state_;
    
    Tx();
};

class TxClear : public Tx {
};

class CacheTx : public Tx {
public:
    bool    uncached;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;
    virtual void push(VTOP *dut) = 0;
    virtual void pull(VTOP *dut) = 0;
    virtual bool check(Ram *ram);
    virtual bool hit();
};

class ICacheTx : public CacheTx {
public:
    u32     araddr;
    std::array<u32, 4> rdata;
    bool    rhit;

    ICacheTx();
    virtual void push(VTOP *dut) override;
    virtual void pull(VTOP *dut) override;
};

class ICacheTxR: public ICacheTx {
public:
    ICacheTxR(u32 araddr);

    virtual bool check(Ram *ram);
    virtual bool hit();
};

class ICacheTxUR: public ICacheTxR {
public:
    ICacheTxUR(u32 araddr);
    virtual bool hit();
};

class DCacheTx : public CacheTx {
public:
    bool    op;
    u32     addr;
    bool    uncached;
    u32     rdata;
    bool    rhit;
    u8      awstrb;
    u32     wdata;
    bool    whit;

    DCacheTx();

    virtual void push(VTOP *dut) override;
    virtual void pull(VTOP *dut) override;
};

class DCacheTxR : public DCacheTx {
public:
    DCacheTxR(u32 addr);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

class DCacheTxW: public DCacheTx {
public:
    DCacheTxW(u32 addr, u8 awstrb, u32 wdata);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

#endif
