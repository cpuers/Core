FW_SRCS = main.cpp ram.cpp tx.cpp
FW_VSRCS = axi_ram.v cache_test_top.v
FW_INC_PATH = .
TOP = cache_test_top

ifeq ($(ICACHE_MODULE),) 
$(error Please set $$ICACHE_MODULE in Makefile.)
endif

ifeq ($(DCACHE_MODULE),) 
$(error Please set $$DCACHE_MODULE in Makefile.)
endif

VERILATOR_FLAGS += -DICACHE_MODULE=$(ICACHE_MODULE) -DDCACHE_MODULE=$(DCACHE_MODULE)
