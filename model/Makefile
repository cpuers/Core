VSRCS := $(VSRCS_TEST) $(shell find vsrc -name '*.v' -or -name '*.sv') \
    $(shell find myCPU -name '*.v' -or -name '*.sv')
INC_PATH += vsrc myCPU

# Rules for hardware model

ifeq ($(MAKECMDGOALS),)
	MAKECMDGOALS  = archive
	.DEFAULT_GOAL = archive
endif

ifeq ($(findstring $(MAKECMDGOALS),clean|clean-all),)

ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
endif
ifeq ($(TOP),)
$(error Must specify top module by `TOP=...`)
endif

endif

WORK_DIR = $(shell pwd)
DST_DIR  = $(WORK_DIR)/build/$(TOP)
$(shell mkdir -p $(DST_DIR))

ARCHIVE  = $(WORK_DIR)/build/lib$(TOP).a

INCFLAGS = $(addprefix -I, $(INC_PATH))
BUILD_FLAGS = --build -j -MMD -O3 -cc -Wall --trace-fst
VERILATOR_FLAGS = $(BUILD_FLAGS) $(INCFLAGS)

$(ARCHIVE): $(VSRCS)

archive: $(ARCHIVE)
	$(VERILATOR) $(VERILATOR_FLAGS) \
	    -Mdir $(DST_DIR) --lib-create $(TOP) \
	    --top-module $(TOP) \
	    $(VSRCS)
	@ln -sfn ./$(TOP)/lib$(TOP).a build/lib$(TOP).a 
	@ln -sfn ./V$(TOP).h build/$(TOP)/VTOP.h # hack for tb-framework

.PHONY: archive

clean:
	rm -rf build/
.PHONY: clean
