#include <verilated.h>
#include <verilated_fst_c.h>
#include <VTOP.h> // hack

int main(int argc, char **argv, char **envp) {
    VerilatedContext* ctxp = new VerilatedContext;
    VerilatedFstC*    fstp = new VerilatedFstC;

    ctxp->traceEverOn(true);
    ctxp->commandArgs(argc, argv);

    VTOP*             dut  = new VTOP;

    dut->trace(fstp, 0);
    fstp->open("build/" TEST ".fst");

    while (!ctxp->gotFinish()) {
        ctxp->timeInc(1);

        if (ctxp->time() < 1000) {
            dut->a = rand();
            dut->b = rand();
            dut->eval();
            IData f = dut->f;
            assert(f == dut->a + dut->b);

            fstp->dump(ctxp->time());
        } else {
            break;
        }
    }
    dut->final();
    fstp->close();

    delete dut;
    delete fstp;
    delete ctxp;
    return 0;
}
