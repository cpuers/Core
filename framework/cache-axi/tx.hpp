#ifndef TX_HPP
#define TX_HPP

#include <common.hpp>
#include <array>
#include <VTOP.h>
#include <ram.hpp>

#include <unordered_set>

namespace std {
    template <typename T, size_t N>
    struct hash<array<T, N>> {
        size_t operator()(const array<T, N> &v) const {
            size_t seed = 0;
            for (const auto& e: v) {
                seed ^= hash<T>{}(e) + 0x9e3779b9U + (seed << 6) + (seed >> 2);
            }
            return seed;
        }
    };
}

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
    bool    uncached;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;
    virtual void push(VTOP *dut) = 0;
    virtual void pull(VTOP *dut) = 0;
    virtual void watch(Ram *ram);
    virtual bool check(Ram *ram);
    virtual bool hit();
};

class ICacheTx : public CacheTx {
public:
    using r_t = std::array<u32, 4>;
    u32     araddr;
    r_t     rdata;
    bool    rhit;

    ICacheTx();
    virtual void push(VTOP *dut) override;
    virtual void pull(VTOP *dut) override;
};

class ICacheTxR: public ICacheTx {
protected:
    set<r_t> values;
public:
    ICacheTxR(u32 araddr);

    virtual void watch(Ram *ram) override;
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
protected:
    set<u32> values;
public:
    DCacheTxR(u32 addr);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;

    virtual void watch(Ram *ram) override;
};

class DCacheTxW: public DCacheTx {
public:
    DCacheTxW(u32 addr, u8 awstrb, u32 wdata);

    virtual bool check(Ram *ram) override;
    virtual bool hit() override;
};

#endif
