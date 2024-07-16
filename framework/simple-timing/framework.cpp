#include <common.hpp>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include <VTOP.h> // hack

#include <testbench.hpp>

static VerilatedContext* ctxp = nullptr;
static VerilatedFstC*    fstp = nullptr;
static VTOP*             dut  = nullptr;
static Testbench*        tb   = nullptr;

static void reset() {
    u64 cnt = tb->reset(dut);
    if (cnt % 2) cnt += 1;
    dut->clock = 0;
    dut->reset = 1;
    while (cnt --) {
        ctxp->timeInc(1);
        dut->clock = !dut->clock;
        dut->eval();
        fstp->dump(ctxp->time());
    }
    dut->reset = 0;
}

int main(int argc, char **argv, char **envp) {

    ctxp = new VerilatedContext;
    fstp = new VerilatedFstC;

    ctxp->traceEverOn(true);
    ctxp->commandArgs(argc, argv);

    dut  = new VTOP;
    
    dut->trace(fstp, 0);
    fstp->open("build/" TEST ".fst");

    tb   = new Testbench(argc, argv);

    reset();

    bool success = true;
    while (!ctxp->gotFinish()) {
        ctxp->timeInc(1);
        dut->clock = !dut->clock;

        if (!dut->clock) {
            if (tb->step(dut, ctxp->time())) {
                break;
            }
        }

        dut->eval();
        fstp->dump(ctxp->time());

        if (dut->clock) {
            if (!tb->check(dut, ctxp->time())) {
                success = false;
                break;
            }
        }
    }

    ctxp->timeInc(1);
    dut->eval();
    fstp->dump(ctxp->time());

    dut->final();
    fstp->close();

    delete dut;
    delete fstp;
    delete ctxp;
    delete tb;
    return success ? 0 : 1;
}
