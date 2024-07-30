#ifndef TX_HPP
#define TX_HPP

#include <common.hpp>
#include <array>
#include <VTOP.h>
#include <ram.hpp>
#include <unordered_set>
#include <cache.hpp>

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
protected:
    template <typename T>
    using set = std::unordered_set<T>;
public:
    virtual void push(VTOP *dut) = 0;
    virtual void pull(VTOP *dut) = 0;
    virtual bool check(Ram *ram);
    virtual bool hit();
};

class ICacheTx : public CacheTx {
public:
    bool    uncached;
    u32     araddr;
    ir_t    rdata;
    bool    rhit;

    ICacheTx();
    virtual void push(VTOP *dut) override;
    virtual void pull(VTOP *dut) override;
};

class ICacheTxR: public ICacheTx {
public:
    ICacheTxR(u32 araddr);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

class ICacheTxRH: public ICacheTxR {
public:
    ICacheTxRH(u32 addr);
    virtual bool check(Ram *ram) override;
};

class ICacheTxUR: public ICacheTx {
public:
    ICacheTxUR(u32 araddr);
    virtual bool hit();
};

class DCacheTx : public CacheTx {
public:
    bool    op;
    u32     addr;
    bool    uncached;
    dr_t    rdata;
    bool    rhit;
    u8      awstrb;
    dw_t    wdata;
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
    DCacheTxW(u32 addr, u8 awstrb, dw_t wdata);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

class DCacheTxRH: public DCacheTxR {
public:
  DCacheTxRH(u32 addr);
  virtual bool check(Ram *ram) override;
};

class DCacheTxWH: public DCacheTxW {
public:
  DCacheTxWH(u32 addr, u8 awstrb, u32 wdata);
  virtual bool check(Ram *ram) override;
};

#endif
