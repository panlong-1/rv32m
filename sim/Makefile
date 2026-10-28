# Optional shortcuts — canonical commands live in ../scripts/
#   ./scripts/run_case.sh …        ./scripts/regress.sh …
SHELL := /usr/bin/env bash

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT         := $(abspath $(MAKEFILE_DIR)/..)

CASE   ?= smoke
CASE_CANON := $(CASE)
CASE_CANON := $(patsubst load_store,loadstore,$(CASE_CANON))
ASM    ?= $(ROOT)/tests/core/asm/$(CASE_CANON).S

MAX_CYCLES ?=
BUILD_DIR  ?=

VCD  ?= 0
TRACE ?= 0
PC_TRACE ?= 0
PC_TRACE_EACH_CYCLE ?= 0
PC_TRACE_FILE ?=

REGRESS_CASE ?=

RUN_CASE := $(ROOT)/scripts/run_case.sh
REGRESS  := $(ROOT)/scripts/regress.sh
ENV_SH   := $(ROOT)/scripts/open_rv.sh

RUN_OPTS := $(if $(filter 1,$(VCD)),--vcd)
RUN_OPTS += $(if $(filter 1,$(TRACE)),--trace)
RUN_OPTS += $(if $(filter 1,$(PC_TRACE)),--pc-trace)
RUN_OPTS += $(if $(filter 1,$(PC_TRACE_EACH_CYCLE)),--pc-trace-each-cycle)
RUN_OPTS += $(if $(PC_TRACE_FILE),--pc-trace-file $(PC_TRACE_FILE))
RUN_OPTS += $(if $(MAX_CYCLES),--max-cycles $(MAX_CYCLES))
RUN_OPTS += $(if $(BUILD_DIR),--build-dir $(BUILD_DIR))

REGRESS_OPTS := $(if $(REGRESS_CASE),--case $(REGRESS_CASE))
REGRESS_OPTS += $(if $(filter 1,$(VCD)),--waves)
REGRESS_OPTS += $(if $(filter 1,$(TRACE)),--trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE)),--pc-trace)
REGRESS_OPTS += $(if $(filter 1,$(PC_TRACE_EACH_CYCLE)),--pc-trace-each-cycle)

.DEFAULT_GOAL := help

.PHONY: help env run regress list gtkwave clean clean-results

help:
	@echo "Shortcuts only — use scripts from the repo root when possible:"
	@echo "  $(ROOT)/scripts/run_case.sh [opts] tests/core/asm/<case>.S"
	@echo "  $(ROOT)/scripts/regress.sh [opts]"
	@echo
	@echo "This Makefile forwards to those scripts (Verilator, TORV SoC):"
	@echo "  make run CASE=smoke              # single case (load_store aliases to loadstore)"
	@echo "  make regress                     # full regression (regress/cases/soc.list)"
	@echo "  make regress REGRESS_CASE=alu    # one case (--case alu)"
	@echo "  VCD=1  TRACE=1  PC_TRACE=1  MAX_CYCLES=N  BUILD_DIR=…"
	@echo "  make list   make env   make gtkwave CASE=…   make clean   make clean-results"

env:
	@source "$(ENV_SH)" >/dev/null; \
	echo "RV32M_ROOT=$$RV32M_ROOT"; \
	echo "VERILATOR=$$(command -v verilator || true)"; \
	echo "GTKWAVE=$$(command -v gtkwave || true)"; \
	echo "TOOLCHAIN=$$TOOLCHAIN"; \
	echo "PDK_ROOT=$$PDK_ROOT"

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

regress:
	@source "$(ENV_SH)" >/dev/null; \
	cd "$(ROOT)"; \
	echo "+ $(REGRESS) $(REGRESS_OPTS)"; \
	"$(REGRESS)" $(REGRESS_OPTS)

list:
	@find "$(ROOT)/tests/core/asm" -maxdepth 1 -name '*.S' -printf '%f\n' | sort

gtkwave:
	@source "$(ENV_SH)" >/dev/null; \
	cd "$(ROOT)"; \
	exec ./scripts/open_gtkwave.sh "$(CASE_CANON)"

clean:
	rm -rf "$(ROOT)/build/sim"

clean-results:
	rm -rf "$(ROOT)/regress/results"
