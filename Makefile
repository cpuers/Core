TESTS = $(dir $(shell find tests -name 'Makefile'))

$(info $(TESTS))

test-all: $(TESTS)

$(TESTS):
	-@$(MAKE) -s -C $@ run

.PHONY: test-all $(TESTS)
.DEFAULT_GOAL = test-all
