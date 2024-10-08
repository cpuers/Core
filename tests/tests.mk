# Rules for tests

ifeq ($(MAKECMDGOALS),)
    MAKECMDGOALS  = binary
    .DEFAULT_GOAL = binary
endif

WORK_DIR = $(shell pwd)
DST_DIR  = $(WORK_DIR)/build
$(shell mkdir -p $(DST_DIR))

ifneq ($(FW),)
    FW_DIR = $(CORE_HOME)/framework/$(FW)
    ifeq ($(wildcard $(FW_DIR)),)
        $(error Select $$FW in $$CORE_HOME/framework.)
    endif
    $(shell ln -sf -T $(FW_DIR) framework)
    ifeq ($(wildcard framework/framework.mk),)
        SRCS += $(shell find framework/ -name '*.cpp')
        VSRCS += $(shell find framework/ -name '*.v')
        INC_PATH += framework/ $(abspath framework/)
    else 
        -include framework/framework.mk
        SRCS += $(addprefix framework/,$(FW_SRCS))
        VSRCS += $(addprefix framework/,$(FW_VSRCS))
        INC_PATH += $(addprefix framework/,$(FW_INC_PATH))
    endif
    SRCS += $(shell find $(CORE_HOME)/framework/common/ -name '*.cpp')
    VSRCS += $(shell find $(CORE_HOME)/framework/common/ -name '*.v')
    INC_PATH += $(CORE_HOME)/framework/common
endif

ifeq ($(findstring $(MAKECMDGOALS),clean|clean-all),)

$(info # Building $(NAME))
ifeq ($(wildcard $(CORE_HOME)/tests/tests.mk),)
    $(error $$CORE_HOME must be Core's repo.)
endif
ifeq ($(VERILATOR_INCLUDE),)
    VERILATOR_INCLUDE=$(shell realpath $$(dirname $$(which verilator))/../share/verilator/include)
endif
ifeq ($(TOP),)
    $(error $$TOP must be set, check test specific Makefile.)
endif

endif

VSRCS := $(sort $(realpath $(VSRCS)))

BINARY_REL = build/$(NAME)
BINARY     = $(abspath $(BINARY_REL))
WAVE_REL   = build/$(NAME).fst
WAVE       = $(abspath $(WAVE_REL))
WAVE_CFG   = $(abspath $(NAME).gtkw)
ARCHIVE    = $(WORK_DIR)/build/$(NAME).a

OBJS  	 = $(addprefix $(DST_DIR)/, $(addsuffix .o, $(basename $(SRCS))))
LIBS 	:= model
LINKAGE  = $(OBJS) \
    $(addsuffix .a, \
        $(addsuffix /build/lib*, \
			$(addprefix $(CORE_HOME)/, $(LIBS)))) \
    -lz # zlib


INC_PATH += . \
    $(addsuffix /build/$(TOP), $(addprefix $(CORE_HOME)/, $(LIBS))) \
    $(addsuffix /include/, $(addprefix $(CORE_HOME)/, $(LIBS))) \
	$(VERILATOR_INCLUDE) $(VERILATOR_INCLUDE)/vltstd
INCFLAGS += $(addprefix -I, $(INC_PATH))

CFLAGS += -ggdb -MMD -Wall -Werror -fPIC $(INCFLAGS) \
          -DVTOP=V$(TOP) -DTEST=\"$(NAME)\"
CXXFLAGS += $(CFLAGS)
ASFLAGS += -MMD $(INCFLAGS)

LD   = g++

binary: $(BINARY)

run: $(BINARY)
	@if $(BINARY) ; then \
        printf '\x1b[0m[%20s] \x1b[32;1mPASSED\033[0m\n' '$(NAME)' ; \
    else \
        printf '\x1b[0m[%20s] \x1b[31;1mFAILED\033[0m\n' '$(NAME)' ; \
    fi

gdb: $(BINARY)
	@gdb -q $(BINARY)

wave: $(WAVE)
	@gtkwave --save $(WAVE_CFG) $(WAVE)

$(DST_DIR)/%.o: %.c
	@mkdir -p $(dir $@) && echo + CC $<
	@$(CC) -std=gnu11 $(CFLAGS) -c -o $@ $(realpath $<)

$(DST_DIR)/%.o: %.cc
	@mkdir -p $(dir $@) && echo + CXX $<
	@$(CXX) -std=c++20 $(CXXFLAGS) -c -o $@ $(realpath $<)

$(DST_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@) && echo + CXX $<
	@$(CXX) -std=c++20 $(CXXFLAGS) -c -o $@ $(realpath $<)

$(DST_DIR)/%.o: %.S
	@mkdir -p $(dir $@) && echo + AS $<
	@$(AS) $(ASFLAGS) -c -o $@ $(realpath $<)

$(LIBS): %:
	@$(MAKE) -s -C $(CORE_HOME)/$* \
        TOP=$(TOP) VSRCS_TEST="$(VSRCS)" VERILATOR_FLAGS_TEST="$(VERILATOR_FLAGS)" \
        archive

$(ARCHIVE): $(OBJS)
	@echo + AR "->" $(shell realpath $@ --relative-to .)
	@ar rcs $(ARCHIVE) $(OBJS)

$(BINARY): $(LIBS) $(OBJS) 
	@echo + LD "->" $(BINARY_REL)
	@$(LD) $(LDFLAGS) -o $(BINARY) -Wl,--start-group $(LINKAGE) -Wl,--end-group

$(WAVE): $(BINARY)
	@echo "=== SIMULATION BEGIN ==="
	-@$(BINARY)
	@echo "=== SIMULATION END   ==="

-include $(addprefix $(DST_DIR)/, $(addsuffix .d, $(basename $(SRCS))))

archive: $(ARCHIVE)
.PHONY: binary archive run wave $(LIBS)

clean:
	rm -rf $(WORK_DIR)/build/
	rm -f $(WORK_DIR)/framework

clean-model:
	-@$(MAKE) -s -C $(CORE_HOME)/model/ clean
.PHONY: clean

CLEAN_ALL = $(dir $(shell find . -mindepth 2 -name Makefile))
clean-all: $(CLEAN_ALL) clean clean-model
$(CLEAN_ALL):
	-@$(MAKE) -s -C $@ clean
.PHONY: clean-all $(CLEAN_ALL)
