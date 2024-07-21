#include <common.hpp>

#include <verilated.h>
#include <verilated_fst_c.h>
#include <VTOP.h>

#include <ram.hpp>
#include <tx.hpp>
#include <testbench.hpp>
#include <queue>

class Dut {
private:
    VerilatedContext* ctxp;
    VerilatedFstC* fstp;
    VTOP* const dut;

    // request waiting, pipeline passing, data waiting
    std::queue<ICacheTx *> tx_i, p_i, rx_i;
    std::queue<DCacheTx *> tx_d, p_d, rx_d;

    // tx_* -> p_* -> rx_*

    u64 timestamp;
    void update_timestamp() {
        timestamp = ctxp->time();
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
        dut->i_valid = dut->d_valid = false;

        delay(3);
        dut->final();
        fstp->close();

        delete dut;
        delete fstp;
        delete ctxp;
    }

    bool stall() {
        return ctxp->time() - timestamp > 100;
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
            fprintf(stderr, "Stall at %lu\n", ctxp->time());
            fprintf(stderr, "queues: i: %d %d %d, d: %d %d %d\n", 
                    tx_i.empty(), p_i.empty(), rx_i.empty(),
                    tx_d.empty(), p_d.empty(), rx_d.empty());
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

    void send(Tx *tx) {
        if (auto itx = dynamic_cast<ICacheTx *>(tx)) {
            tx_i.push(itx);
        } else if (auto dtx = dynamic_cast<DCacheTx *>(tx)) {
            tx_d.push(dtx);
        } else {
            assert(false);
        }
    }

    Tx *receive() {
        if (!rx_i.empty()) {
            auto r =  rx_i.front();
            rx_i.pop();
            return r;
        }
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
    Testbench tb(argc, argv);
    for (auto t : tb.tests()) {
        dut.send(t);
    }
    while (!dut.finish()) {
        dut.step();
        while (auto t = dut.receive()) {
            if (auto i = dynamic_cast<ICacheTx *>(t)) {
                std::array<u32, 4> e = ram.iread(i->araddr);
                auto r = i->rdata;
                if (i->rdata != r) {
                    printf("ICache Read: %08x, [%lu -- %lu]\n", i->araddr, i->st, i->ed);
                    printf("Expected: [%08x %08x %08x %08x]\n", e[0], e[1], e[2], e[3]);
                    printf("Result  : [%08x %08x %08x %08x]\n", r[0], r[1], r[2], r[3]);
                    return 1;
                }
                delete i;
            } else if (auto d = dynamic_cast<DCacheTx *>(t)) {
                u32 e = ram.dread(d->addr);
                u32 r = d->rdata;
                if (e != r) {
                    printf("DCache Read: %08x, [%lu -- %lu]\n", d->addr, d->st, d->ed);
                    printf("Expected: %08x\nResult  : %08x\n", e, r);
                    return 1;
                }
                delete d;
            }
        }
    }
    return 0;
}
