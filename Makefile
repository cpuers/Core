TESTS = $(dir $(shell find tests -name 'Makefile'))

test-all: $(TESTS)

$(TESTS):
	-@$(MAKE) -s -C $@ run

.PHONY: test-all
.DEFAULT_GOAL = test-all
