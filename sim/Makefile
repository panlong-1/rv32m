# Optional shortcuts — canonical commands live in ../scripts/
#   ./scripts/run_case.sh …        ./scripts/regress.sh …
SHELL := /usr/bin/env bash

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOT         := $(abspath $(MAKEFILE_DIR)/..)

SIM ?= verilator

TARGET ?= soc
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
ENV_SH   := $(ROOT)/scripts/open_rv.sh

RUN_OPTS := --target $(TARGET)
RUN_OPTS += --sim $(SIM)
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
REGRESS_OPTS += --sim $(SIM)
REGRESS_OPTS += $(if $(REGRESS_CASE),--case $(REGRESS_CASE))
REGRESS_OPTS += $(if $(filter 1,$(FSDB)),--fsdb)
REGRESS_OPTS += $(if $(filter 1,$(VCD)),--waves)
REGRESS_OPTS += $(if $(filter 1,$(TRACE)),--trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE)),--pc-trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE_EACH_CYCLE)),--pc-trace-each-cycle)

.DEFAULT_GOAL := help

.PHONY: help env run core ahb regress list verdi gtkwave clean clean-results

help:
	@echo "Shortcuts only — use scripts from the repo root when possible:"
	@echo "  $(ROOT)/scripts/run_case.sh [opts] tests/core/asm/<case>.S"
	@echo "  $(ROOT)/scripts/regress.sh [opts]"
	@echo
	@echo "This Makefile forwards to those scripts:"
	@echo "  make run CASE=smoke              # core single case"
	@echo "  make ahb CASE=sbus               # AHB (load_store aliases to loadstore)"
	@echo "  make regress                     # full regress for TARGET (default core)"
	@echo "  make regress REGRESS_CASE=alu    # one case (--case alu)"
	@echo "  make regress TARGET=ahb          # AHB regress"
	@echo "  SIM=verilator|vcs  FSDB=1 VCD=1  PC_TRACE=1  KDB=1  MAX_CYCLES=N  BUILD_DIR=…"
	@echo "  make list   make env   make verdi   make gtkwave   make clean   make clean-results"

env:
	@source "$(ENV_SH)" >/dev/null; \
	echo "RV32M_ROOT=$$RV32M_ROOT"; \
	echo "VERILATOR=$$(command -v verilator || true)"; \
	echo "VCS=$$(command -v vcs || true)"; \
	echo "GTKWAVE=$$(command -v gtkwave || true)"; \
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

gtkwave:
	@source "$(ENV_SH)" >/dev/null; \
	cd "$(ROOT)"; \
	exec ./scripts/open_gtkwave.sh --target "$(TARGET)" "$(CASE_CANON)"

clean:
	rm -rf "$(ROOT)/build/sim/core" "$(ROOT)/build/sim/ahb"

clean-results:
	rm -rf "$(ROOT)/regress/results"
