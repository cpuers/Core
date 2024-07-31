#ifndef TESTBENCH_HPP
#define TESTBENCH_HPP

#include <common.hpp>
#include <vector>
#include <tx.hpp>

class Testbench {
public:
    Testbench(int argc, char **argv);
    ~Testbench();
    std::vector<Tx *> tests();
};

#endif
