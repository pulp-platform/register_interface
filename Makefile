# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Philippe Sauter <phsauter@iis.ee.ethz.ch>

BENDER ?= bender
VSIM   ?= questa-2022.3 vsim

.DEFAULT_GOAL := help

TESTS := simple_registers axi_to_reg_v2
GUI   ?= 0
DEBUG ?= 0

BENDER_TARGET_simple_registers := register_interface_test
BENDER_TARGET_axi_to_reg_v2   := axi_to_reg_v2_test
TB_simple_registers := tb_simple_registers
TB_axi_to_reg_v2   := tb_axi_to_reg_v2

ifeq ($(GUI),1)
  VSIM_MODE :=
else
  VSIM_MODE := -c
endif

VSIM_VOPTARGS :=
ifneq ($(filter 1,$(GUI) $(DEBUG)),)
  VSIM_VOPTARGS := -voptargs=+acc
endif

## Build and run the complete test suite
all: $(TESTS:%=run-%)

## Run the simple-registers testbench
run-simple_registers:

## Run the AXI-to-register-interface-v2 testbench
run-axi_to_reg_v2:

## Remove generated simulator build files
clean:
	rm -rf scripts/compile.*.tcl work

#################
# Documentation #
#################

## Print available targets
help: Makefile
	@printf "Available targets:\n------------------\n"
	@for mkfile in $(MAKEFILE_LIST); do \
		awk '/^[a-zA-Z_0-9-]+:/ { \
			helpMessage = match(lastLine, /^## (.*)/); \
			if (helpMessage) { \
				helpCommand = substr($$1, 0, index($$1, ":")-1); \
				helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
				printf "%-24s %s\n", helpCommand, helpMessage; \
			} \
		} \
		{ lastLine = $$0 }' $$mkfile; \
	done

define test_template
scripts/compile.$(1).tcl: Bender.yml
	mkdir -p scripts
	$(BENDER) script vsim -t rtl -t test -t simulation -t $(BENDER_TARGET_$(1)) --vlog-arg='-timescale "1 ns / 1 ns"' > $$@

build-$(1): scripts/compile.$(1).tcl
	$(VSIM) -c -do "do $$<; exit"

run-$(1): build-$(1)
	$(VSIM) $(VSIM_MODE) -do "vsim $(TB_$(1)) -t 1ps $(VSIM_VOPTARGS); onfinish exit; run -all; exit"
endef

$(foreach test,$(TESTS),$(eval $(call test_template,$(test))))

.PHONY: all clean help $(TESTS:%=build-%) $(TESTS:%=run-%)
