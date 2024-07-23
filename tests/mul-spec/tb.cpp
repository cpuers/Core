

#include <Verilator>
#include "Vmul.h"
#include "testbench.hpp"

#include <iostream>
#include <random>
#include <ctime>

#define TESTLOOP 100000
#define PERCENT(x) (rand() % 100 < (x) ? true : false)

u32 margin_cond[] = {
    0,-1,1,0x7fffffff,0xffffffff
}

Testbench::Testbench(int argc, char **argv) { }
Testbench::~Testbench() {}
u64 Testbench::reset(Vmul *dut) {}



int main () {
    srand(time(0));
    for(int i=0; i<TESTLOOP; i++) {
        bool sign = PERCENT(50);
        u32 mul0, mul1;
        if(PERCENT(15)) mul0 = margin_cond[rand() % 5];
        else mul0 = rand();
        if(PERCENT(15)) mul1 = margin_cond[rand() % 5];
        else mul1 = rand();
        u64 ref;
        if(sign) {
            ref = (i64)mul0 * (i64)mul1;
        }else  {
            ref = (u64)mul0 * (u64)mul1;
        }
        dut->x = mul0;
        dut->y = mul1;
        dut->mul_signed = sign;
        dut->eval();
        if(dut->result != ref){
            std::cerr << "FAULT: " << mul0 << " * " << mul1 << " ref:" << ref << " dut:" << dut->result << std::endl;
            goto FAULT; 
        }
    }
    std::cout << "PASS!\n"; 
    return 0;
FAULT:
    return -1;
}