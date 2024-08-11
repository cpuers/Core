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
protected:
    void set_addr_strb(u32 addr, u8 strb);
public:
    bool    op;
    u32     addr;
    bool    uncached;
    dr_t    rdata;
    bool    rhit;
    u8      strb;
    dw_t    wdata;
    bool    whit;

    DCacheTx();

    virtual void push(VTOP *dut) override;
    virtual void pull(VTOP *dut) override;
    static u8 rand_strb(u32 addr);
};

class DCacheTxR : public DCacheTx {
public:
    DCacheTxR(u32 addr, u8 strb);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;

};

class DCacheTxW: public DCacheTx {
public:
    DCacheTxW(u32 addr, u8 strb, dw_t wdata);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

class DCacheTxRH: public DCacheTxR {
public:
  DCacheTxRH(u32 addr, u8 strb);
  virtual bool check(Ram *ram) override;
};

class DCacheTxWH: public DCacheTxW {
public:
  DCacheTxWH(u32 addr, u8 strb, u32 wdata);
  virtual bool check(Ram *ram) override;
};

class CacheTxCacop: public CacheTx {
public:
    // 0: L1 I, 1: L1 D
    bool    operand;
    u8      code;
    u32     addr;
    CacheTxCacop(bool operand, u8 code, u32 addr) {
        this->operand = operand;
        this->code = code;
        this->addr = addr % MEM_SIZE;
    }

    virtual void push(VTOP *dut) override {
        if (operand) {
            dut->d_cacop_code = code;
            dut->d_cacop_addr = addr;
        } else {
            dut->i_cacop_addr = code;
            dut->i_cacop_addr = addr;
        }
    }

    virtual void pull(VTOP *dut) override {}

    virtual bool check(Ram *ram) override {
        return true;
    }
    virtual bool hit() override {
        return false;
    }
};

class CacheTxCINV: public CacheTxCacop {
public:
    CacheTxCINV(bool operand, u8 way, u16 idx) 
        : CacheTxCacop(operand, 0, (idx << 4) | way) {}
};

class CacheTxCIDX: public CacheTxCacop {
public:
    CacheTxCIDX(bool operand, u8 way, u16 idx) 
        : CacheTxCacop(operand, 1, (idx << 4) | way) {}
};

class CacheTxCLOOKUP: public CacheTxCacop {
public:
    CacheTxCLOOKUP(bool operand, u32 addr) 
        : CacheTxCacop(operand, 2, addr) {}
};

class DCacheTxCINV: public CacheTxCINV {
public:
    DCacheTxCINV(u8 way, u16 idx) : CacheTxCINV(true, way, idx) {}
};

class DCacheTxCIDX: public CacheTxCIDX {
public:
    DCacheTxCIDX(u8 way, u16 idx) : CacheTxCIDX(true, way, idx) {}
};

class DCacheTxCLOOKUP: public CacheTxCLOOKUP {
public:
    DCacheTxCLOOKUP(u32 addr) : CacheTxCLOOKUP(true, addr) {}
};

class DCacheTxFlushRW: public Tx {};

#endif
