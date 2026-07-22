# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Philippe Sauter <phsauter@iis.ee.ethz.ch>

BENDER ?= bender
VSIM   ?= questa-2022.3 vsim

TESTS := simple_registers axi_to_reg_v2
TEST  ?= axi_to_reg_v2

BENDER_TARGET_simple_registers := register_interface_test
BENDER_TARGET_axi_to_reg_v2   := axi_to_reg_v2_test
TB_simple_registers := tb_simple_registers
TB_axi_to_reg_v2   := tb_axi_to_reg_v2

ifeq ($(GUI),1)
  VSIM_MODE :=
else
  VSIM_MODE := -c
endif

all: $(TESTS:%=run-%)

test: run-$(TEST)

clean:
	rm -rf scripts/compile.*.tcl work

define test_template
scripts/compile.$(1).tcl: Bender.yml
	mkdir -p scripts
	$(BENDER) script vsim -t rtl -t test -t simulation -t $(BENDER_TARGET_$(1)) --vlog-arg='-timescale "1 ns / 1 ns"' > $$@

build-$(1): scripts/compile.$(1).tcl
	$(VSIM) -c -do "do $$<; exit"

run-$(1): build-$(1)
	$(VSIM) $(VSIM_MODE) -do "vsim $(TB_$(1)) -t 1ps -voptargs=+acc; onfinish exit; run -all; exit"
endef

$(foreach test,$(TESTS),$(eval $(call test_template,$(test))))

.PHONY: all test clean $(TESTS:%=build-%) $(TESTS:%=run-%)
