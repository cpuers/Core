#include <cassert>
#include <common.hpp>

#include <cstdio>
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

    u64 timestamp_i, timestamp_d;
    void update_timestamp_i() {
        timestamp_i = ctxp->time();
    }
    void update_timestamp_d() {
        timestamp_d = ctxp->time();
    }
    void update_timestamp() {
        update_timestamp_i();
        update_timestamp_d();
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

        delay(10);
        dut->final();
        fstp->close();

        delete dut;
        delete fstp;
        delete ctxp;
    }

    bool empty_i() {
        return tx_i.empty() && rx_i.empty() && p_i.empty();
    }

    bool empty_d() {
        return tx_d.empty() && rx_d.empty() && p_d.empty();
    }

    bool stall() {
        return 
            (!empty_i() && (ctxp->time() - timestamp_i > 100)) || 
            (!empty_d() && (ctxp->time() - timestamp_d > 100));
    }

    bool finish() {
        return stall() || (
            empty_i() && empty_d()
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
        if (ticks == 0) {
            dut->eval();
            return;
        }
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

        dut->eval();

        if (stall()) {
            fprintf(stderr, "Stall at %lu\n", ctxp->time());
            fprintf(stderr, "queues: i: %d %d %d, d: %d %d %d\n", 
                    tx_i.empty(), p_i.empty(), rx_i.empty(),
                    tx_d.empty(), p_d.empty(), rx_d.empty());
            fprintf(stderr, "ICache update time: %lu, DCache update time: %lu\n", timestamp_i, timestamp_d);
        }
    }

    void step() {
        // Special Judge: DCacheTxW write pulls just after the tick
        DCacheTxW *wdtx = nullptr;
        // Firstly, receive data at output
        if (!p_i.empty()) {
            auto irx = p_i.front();
            if (dut->i_rvalid) {
                irx->ed(ctxp->time());
                irx->pull(dut);
                rx_i.push(irx);
                p_i.pop();
                update_timestamp_i();
            }
        }
        if (!tx_i.empty() && dut->i_valid) {
            auto itx = tx_i.front();
            if (dut->i_ready) {
                p_i.push(itx);
                tx_i.pop();
                itx->st(ctxp->time());
                update_timestamp_i();
            }
        }
        if (!p_d.empty()) {
            auto drx = p_d.front();
            if (dut->d_rvalid) {
                drx->ed(ctxp->time());
                drx->pull(dut);
                rx_d.push(drx);
                p_d.pop();
                update_timestamp_d();
            }
        }
        if (!tx_d.empty() && dut->d_valid) {
            auto dtx = tx_d.front();
            if (dut->d_ready) {
                tx_d.pop();
                dtx->st(ctxp->time());
                update_timestamp_d();
                if (auto rdtx = dynamic_cast<DCacheTxR *>(dtx)) {
                    p_d.push(rdtx);
                } else {
                    wdtx = dynamic_cast<DCacheTxW *>(dtx);
                }
            }
        }
        // Then, update the model in the middle
        delay(1);
        // Special Judge: DCacheTxW
        if (wdtx) {
            wdtx->pull(dut);
            wdtx->ed(ctxp->time());
            rx_d.push(wdtx);
            wdtx = nullptr;
        }
        // Finally, put new data at input
        if (!tx_i.empty()) {
            auto itx = tx_i.front();
            dut->i_valid = true;
            itx->push(dut);
        } else {
            dut->i_valid = false;
        }
        if (!tx_d.empty()) {
            auto dtx = tx_d.front();
            dut->d_valid = true;
            dtx->push(dut);
        } else {
            dut->d_valid = false;
        }
        delay(0);
    }

    void send(CacheTx *tx) {
        if (auto itx = dynamic_cast<ICacheTx *>(tx)) {
            tx_i.push(itx);
        } else if (auto dtx = dynamic_cast<DCacheTx *>(tx)) {
            tx_d.push(dtx);
        } else {
            assert(false);
        }
    }

    CacheTx *receive() {
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

bool step_and_check(Dut &dut, Ram &ram, u32 &tot, u32 &hit) {
    dut.step();
    while (auto t = dut.receive()) {
        if (!t->check(&ram)) {
            delete t;
            return false;
        }
        tot ++;
        hit += t->hit();
        delete t;
    }
    return true;
}

int main(int argc, char **argv, char **envp) {
    Dut dut(argc, argv);
    Ram ram;
    dut.reset(10);
    Testbench tb(argc, argv);
    u32 tot = 0, hit = 0;
    for (auto t : tb.tests()) {
        if (auto ctx = dynamic_cast<CacheTx *>(t)) {
            dut.send(ctx);
            continue;
        } else {
            while (!dut.finish()) {
                if (!step_and_check(dut, ram, tot, hit)) {
                    return 1;
                }
            }
            if (auto txc = dynamic_cast<TxClear *>(t)) {
                (void) txc;
                continue;
            } else {
                assert(false);
            }
        }
    }
    while (!dut.finish()) {
        if (!step_and_check(dut, ram, tot, hit)) {
            return 1;
        }
    }
    if (tot != 0) {
        printf("=== Statistics ===\n");
        printf("Hit / Tot: %u / %u (%.3lf%%)\n", hit, tot, (double)hit*100/tot);
        printf("==================\n");
    }

    return 0;
}
