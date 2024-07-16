TESTS = $(dir $(shell find tests -name 'Makefile'))

$(info $(TESTS))

test-all: $(TESTS)

$(TESTS):
	-@$(MAKE) -s -C $@ run

clean:
	-@$(MAKE) -s -C tests -f tests.mk clean-all
	-@$(MAKE) -s -C model -f Makefile clean

.PHONY: test-all clean $(TESTS)
.DEFAULT_GOAL = test-all
