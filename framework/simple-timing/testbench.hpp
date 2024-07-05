#ifndef TESTBENCH_HPP
#define TESTBENCH_HPP

#include <common.hpp>
#include <VTOP.h> // hack

/*
    To demonstrate timing, assume DUT samples on posedge.

      ┌───┐   ┌───
    ──┘   └───┘
      🡑  🡑    🡑  🡑
      1  2    1  3

    1. DUT samples on posedge;
    2. `step()` is called before negedge;
    3. `check()` is called after the next posedge;

*/

class Testbench VL_NOT_FINAL {
public:
    // Framework passes the original arguments before simulation begins.
    explicit Testbench(int argc, char **argv);
    ~Testbench();


    // The testbench should set [dut]'s input signals at reset,
    // then return the number of ticks during reset.
    u64 reset(VTOP* dut);

    // The testbench should set [dut]'s input signals at [time],
    // then return whether the simulation should finish.
    bool step(VTOP* dut, u64 time);

    // The testbench should check [dut]'s output signals at [time],
    // then return whether it passes the test.
    bool check(VTOP* dut, u64 time);

private:
    VL_UNCOPYABLE(Testbench);
};

#endif
