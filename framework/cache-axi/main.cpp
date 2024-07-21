#include <common.hpp>

#include <verilated.h>
#include <verilated_fst_c.h>
#include <VTOP.h>

#include <ram.hpp>

#include <bits/stdc++.h>

using namespace std;

class CpuTx {
public:
    u64     st;
    u64     ed;

    bool    done;

    CpuTx() : st(0), ed(0), done(false) {}
};

class CpuICacheTx : public CpuTx {
public:
    u32     araddr;
    bool    uncached;
    std::array<u32, 4> rdata;
    bool    cacop_en;
    u8      cacop_code;
    u32     cacop_addr;

    CpuICacheTx() {
        araddr = 0;
        uncached = false;
        rdata = {0, 0, 0, 0};
        cacop_en = false;
        cacop_code = 0;
        cacop_addr = 0;
    }
};

class CpuICacheTxR: public CpuICacheTx {
public:
    CpuICacheTxR(u32 araddr) {
        this->araddr = araddr;
    }
};

class CpuDCacheTx : public CpuTx {
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

    CpuDCacheTx() {
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
};

class CpuDCacheTxR : public CpuDCacheTx {
public:
    CpuDCacheTxR(u32 addr) {
        this->addr = addr;
    }
};

class CpuDCacheTxW: public CpuDCacheTx {
public:
    CpuDCacheTxW(u32 addr, u8 awstrb, u32 wdata) {
        this->addr = addr;
        this->awstrb = awstrb;
        this->wdata = wdata;
    }
};

class Dut {
private:
    VerilatedContext* ctxp;
    VerilatedFstC* fstp;
    VTOP* const dut;

    // request waiting, pipeline passing, data waiting
    std::queue<CpuICacheTx *> tx_i, p_i, rx_i;
    std::queue<CpuDCacheTx *> tx_d, p_d, rx_d;

    // tx_* -> p_* -> rx_*

    u64 timestamp;
    void update_timestamp() {
        timestamp = ctxp->time();
    }

    bool stall() {
        return ctxp->time() - timestamp > 100;
    }
public:
    Dut(int argc, char **argv) : 
        ctxp(new VerilatedContext), 
        fstp(new VerilatedFstC), 
        dut(new VTOP)
    {
        ctxp->traceEverOn(true);
        ctxp->commandArgs(argc, argv);

        dut->trace(fstp, 0);
        fstp->open("build/" TEST ".fst");

        update_timestamp();

        reset(10);
    }
    ~Dut() {
        delay(3);
        dut->final();
        fstp->close();

        delete dut;
        delete fstp;
        delete ctxp;
    }

    bool finish() {
        return stall() || (
            tx_i.empty() && rx_i.empty() && 
            tx_d.empty() && rx_d.empty() &&
            p_i.empty() && p_d.empty()
        );
    }

    void reset(u64 ticks) {
        dut->reset = 1;
        dut->clock = 0;
        dut->i_valid = false;
        dut->d_valid = false;

        delay(ticks);

        dut->reset = 0;

        update_timestamp();
    }

    void delay(u64 ticks) {
        dut->clock = 0;
        for (u64 i = 0; i < ticks; i ++) {
            dut->eval();
            fstp->dump(ctxp->time());
            ctxp->timeInc(1);

            dut->clock = 1;
            dut->eval();
            fstp->dump(ctxp->time());
            ctxp->timeInc(1);

            dut->clock = 0;
        }

        if (stall()) {
            fprintf(stderr, "Stall!\n");
        }
    }

    void step() {
        // Firstly, receive data at output
        if (!p_i.empty()) {
            auto irx = p_i.front();
            if (dut->i_rvalid) {
                irx->ed = ctxp->time();
                for (u32 i = 0; i < 4; i ++) {
                    irx->rdata[i] = dut->i_rdata.at(i);
                }
                rx_i.push(irx);
                p_i.pop();
                update_timestamp();
            }
        }
        if (!tx_i.empty()) {
            auto itx = tx_i.front();
            if (dut->i_ready) {
                p_i.push(itx);
                tx_i.pop();
                itx->st = ctxp->time();
                update_timestamp();
            }
        }
        if (!p_d.empty()) {
            auto drx = p_d.front();
            if (dut->d_rvalid) {
                drx->ed = ctxp->time();
                drx->rdata = dut->d_rdata;
                rx_d.push(drx);
                p_d.pop();
                update_timestamp();
            }
        }
        if (!tx_d.empty()) {
            auto dtx = tx_d.front();
            if (dut->d_ready) {
                p_d.push(dtx);
                tx_d.pop();
                dtx->st = ctxp->time();
                update_timestamp();
            }
        }
        // Then, update the model in the middle
        delay(1);
        // Finally, put new data at input
        if (!tx_i.empty()) {
            auto itx = tx_i.front();
            dut->i_valid = true;
            dut->i_araddr     = itx->araddr    ;
            dut->i_uncached   = itx->uncached  ;
            dut->i_cacop_en   = itx->cacop_en  ;
            dut->i_cacop_code = itx->cacop_code;
            dut->i_cacop_addr = itx->cacop_addr;
        } else {
            dut->i_valid = false;
        }
        if (!tx_d.empty()) {
            auto dtx = tx_d.front();
            dut->d_valid = true;
            dut->d_op         = dtx->op;
            dut->d_addr       = dtx->addr    ;
            dut->d_uncached   = dtx->uncached  ;
            dut->d_cacop_en   = dtx->cacop_en  ;
            dut->d_cacop_code = dtx->cacop_code;
            dut->d_cacop_addr = dtx->cacop_addr;
        } else {
            dut->d_valid = false;
        }
    }

    void send(CpuICacheTx *tx) {
        tx_i.push(tx);
    }

    void send(CpuDCacheTx *tx) {
        tx_d.push(tx);
    }

    CpuICacheTx *receive_i() {
        if (!rx_i.empty()) {
            auto r =  rx_i.front();
            rx_i.pop();
            return r;
        }
        return nullptr;
    }

    CpuDCacheTx *receive_d() {
        if (!rx_d.empty()) {
            auto r =  rx_d.front();
            rx_d.pop();
            return r;
        }
        return nullptr;
    }
};

int main(int argc, char **argv, char **envp) {
    Dut dut(argc, argv);
    Ram ram;
    ram.init();
    dut.reset(10);
    for (int i = 0; i < 100; i ++) {
        if (rand() & 1) {
            auto t = new CpuICacheTxR(rand());
            dut.send(t);
        } else {
            auto t = new CpuDCacheTxR(rand());
            dut.send(t);
        }
    }
    while (!dut.finish()) {
        dut.step();
        auto i = dut.receive_i();
        if (i) {
            std::array<u32, 4> e = ram.iread(i->araddr);
            auto r = i->rdata;
            if (i->rdata != r) {
                printf("Expected: [%08x %08x %08x %08x]\n", e[0], e[1], e[2], e[3]);
                printf("Result  : [%08x %08x %08x %08x]\n", r[0], r[1], r[2], r[3]);
                return 1;
            }
            delete i;
        }
        auto d = dut.receive_d();
        if (d) {
            u32 e = ram.dread(d->addr);
            u32 r = d->rdata;
            if (e != r) {
                printf("Expected: %08x\nResult  : %08x\n", e, r);
                return 1;
            }
            delete d;
        }
    }
    return 0;
}
