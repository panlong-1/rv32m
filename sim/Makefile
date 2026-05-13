SHELL := /usr/bin/env bash

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOT         := $(abspath $(MAKEFILE_DIR)/..)
PROJECT_ROOT := $(abspath $(ROOT)/..)

TARGET ?= core
CASE   ?= smoke
CASE_CANON := $(CASE)
CASE_CANON := $(patsubst load_store,loadstore,$(CASE_CANON))
ASM    ?= $(ROOT)/tests/core/asm/$(CASE_CANON).S

MAX_CYCLES ?=
BUILD_DIR  ?=

FSDB ?= 0
VCD  ?= 0
TRACE ?= 0
PC_TRACE ?= 0
PC_TRACE_EACH_CYCLE ?= 0
PC_TRACE_FILE ?=
KDB ?= 0

REGRESS_CASE ?=

RUN_CASE := $(ROOT)/scripts/run_case.sh
REGRESS  := $(ROOT)/scripts/regress.sh
ENV_SH   := $(PROJECT_ROOT)/rv

RUN_OPTS := --target $(TARGET)
RUN_OPTS += $(if $(filter 1,$(FSDB)),--fsdb)
RUN_OPTS += $(if $(filter 1,$(VCD)),--vcd)
RUN_OPTS += $(if $(filter 1,$(TRACE)),--trace)
RUN_OPTS += $(if $(filter 1,$(PC_TRACE)),--pc-trace)
RUN_OPTS += $(if $(filter 1,$(PC_TRACE_EACH_CYCLE)),--pc-trace-each-cycle)
RUN_OPTS += $(if $(PC_TRACE_FILE),--pc-trace-file $(PC_TRACE_FILE))
RUN_OPTS += $(if $(filter 1,$(KDB)),--kdb)
RUN_OPTS += $(if $(MAX_CYCLES),--max-cycles $(MAX_CYCLES))
RUN_OPTS += $(if $(BUILD_DIR),--build-dir $(BUILD_DIR))

REGRESS_OPTS := --target $(TARGET)
REGRESS_OPTS += $(if $(REGRESS_CASE),--case $(REGRESS_CASE))
REGRESS_OPTS += $(if $(filter 1,$(FSDB)),--fsdb)
REGRESS_OPTS += $(if $(filter 1,$(VCD)),--waves)
REGRESS_OPTS += $(if $(filter 1,$(TRACE)),--trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE)),--pc-trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE_EACH_CYCLE)),--pc-trace-each-cycle)

.DEFAULT_GOAL := help

.PHONY: help env run core ahb regress regress-core regress-ahb regress-one list verdi clean clean-results

help:
	@echo "rv32m sim Makefile"
	@echo
	@echo "Single case:"
	@echo "  make run CASE=smoke                  # core, tests/core/asm/smoke.S"
	@echo "  make ahb CASE=sbus                   # AHB single case"
	@echo "  make ahb CASE=load_store             # alias for loadstore.S"
	@echo "  make run ASM=/abs/path/foo.S         # explicit asm source"
	@echo "  make run CASE=smoke FSDB=1 PC_TRACE=1"
	@echo
	@echo "Regression:"
	@echo "  make regress                         # core full regression"
	@echo "  make regress-one CASE=alu            # core one case"
	@echo "  make regress-ahb REGRESS_CASE=sbus   # AHB one case"
	@echo
	@echo "Useful variables:"
	@echo "  TARGET=core|ahb  CASE=<stem>  ASM=<file.S>  REGRESS_CASE=<name>"
	@echo "  CASE aliases: load_store -> loadstore"
	@echo "  FSDB=1 VCD=1 TRACE=1 PC_TRACE=1 PC_TRACE_EACH_CYCLE=1 KDB=1"
	@echo "  MAX_CYCLES=N BUILD_DIR=<dir> PC_TRACE_FILE=<file>"
	@echo
	@echo "Other:"
	@echo "  make list                            # list asm cases"
	@echo "  make verdi CASE=smoke TARGET=core    # open last single-case Verdi helper"
	@echo "  make clean                           # remove build/sim/{core,ahb}"
	@echo "  make clean-results                   # remove regress/results"

env:
	@source "$(ENV_SH)" >/dev/null; \
	echo "RV32M_ROOT=$$RV32M_ROOT"; \
	echo "VCS=$$(command -v vcs || true)"; \
	echo "VERDI=$$(command -v verdi || true)"; \
	echo "TOOLCHAIN=$$TOOLCHAIN"; \
	echo "SNPSLMD_LICENSE_FILE=$$SNPSLMD_LICENSE_FILE"

run:
	@source "$(ENV_SH)" >/dev/null; \
	cd "$(ROOT)"; \
	if [[ ! -f "$(ASM)" ]]; then \
	  echo "ASM not found: $(ASM)"; \
	  echo "Use one of:"; \
	  find "$(ROOT)/tests/core/asm" -maxdepth 1 -name '*.S' -printf '  %f\n' | sort; \
	  exit 1; \
	fi; \
	echo "+ $(RUN_CASE) $(RUN_OPTS) $(ASM)"; \
	"$(RUN_CASE)" $(RUN_OPTS) "$(ASM)"

core:
	@$(MAKE) --no-print-directory -f "$(THIS_MAKEFILE)" run TARGET=core

ahb:
	@$(MAKE) --no-print-directory -f "$(THIS_MAKEFILE)" run TARGET=ahb

regress:
	@source "$(ENV_SH)" >/dev/null; \
	cd "$(ROOT)"; \
	echo "+ $(REGRESS) $(REGRESS_OPTS)"; \
	"$(REGRESS)" $(REGRESS_OPTS)

regress-core:
	@$(MAKE) --no-print-directory -f "$(THIS_MAKEFILE)" regress TARGET=core

regress-ahb:
	@$(MAKE) --no-print-directory -f "$(THIS_MAKEFILE)" regress TARGET=ahb

regress-one:
	@$(MAKE) --no-print-directory -f "$(THIS_MAKEFILE)" regress REGRESS_CASE="$(CASE_CANON)"

list:
	@find "$(ROOT)/tests/core/asm" -maxdepth 1 -name '*.S' -printf '%f\n' | sort

verdi:
	@case_dir="$(if $(BUILD_DIR),$(BUILD_DIR),$(ROOT)/build/sim/$(TARGET)/$(basename $(notdir $(ASM))))"; \
	if [[ ! -x "$$case_dir/open_verdi.sh" ]]; then \
	  echo "No open_verdi.sh in $$case_dir. Run the case first."; \
	  exit 1; \
	fi; \
	cd "$$case_dir"; \
	exec ./open_verdi.sh

clean:
	rm -rf "$(ROOT)/build/sim/core" "$(ROOT)/build/sim/ahb"

clean-results:
	rm -rf "$(ROOT)/regress/results"
