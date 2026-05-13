# Run a single asm case from this directory; artifacts go to ./work/<stem>/
#
#   make run alu.S
#
# GNU make still treats the second word as another goal; you may see
#   make: Nothing to be done for `alu.S'.
# after a successful run — that line is harmless (exit code 0).
#
# Alternative (no extra goal):  make run ASM=alu.S
#
# Optional:
#   RUN_FSDB=1 make run alu.S     # needs VERDI_HOME
#   MAX_CYCLES=8000 make run muldiv.S

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT           := $(abspath $(MAKEFILE_DIR)/../../..)
TOOLCHAIN_SH   := $(ROOT)/scripts/toolchain_test.sh

# Default: VCD + KDB for local Verdi (set RV32M_WAVE_VCD=0 / RV32M_VCS_KDB=0 to disable)
RV32M_WAVE_VCD ?= 1
RV32M_VCS_KDB  ?= 1

.PHONY: run help list clean

.DEFAULT_GOAL := help

help:
	@echo "Usage (from this directory):"
	@echo "  make run <file>.S          e.g.  make run alu.S"
	@echo "  make run ASM=alu.S         same, avoids extra make goal on .S file"
	@echo "Artifacts:  ./work/<stem>/  (elf, hex, dump, sim.log, vcs/)"
	@echo "  make list                  list *.S"
	@echo "  make clean                 rm -rf ./work/"
	@echo "Optional: RUN_FSDB=1  MAX_CYCLES=N  (see $(ROOT)/README.md)"
	@echo "Wave/KDB defaults: RV32M_WAVE_VCD=$(RV32M_WAVE_VCD)  RV32M_VCS_KDB=$(RV32M_VCS_KDB)  (override on cmdline)"

list:
	@ls -1 *.S 2>/dev/null || true

clean:
	rm -rf "$(MAKEFILE_DIR)work"

# ASM=... avoids listing the .S file as a second make goal
run:
	@asm="$(ASM)"; \
	if [ -z "$$asm" ]; then asm="$(word 2,$(MAKECMDGOALS))"; fi; \
	if [ -z "$$asm" ] || [ "$$asm" = "run" ]; then \
	  echo "Usage: make run <file>.S   or   make run ASM=alu.S"; exit 1; \
	fi; \
	if [ ! -f "$$asm" ]; then \
	  echo "File not found: $$asm (cwd=$(CURDIR))"; exit 1; \
	fi; \
	stem="$${asm##*/}"; stem="$${stem%.S}"; \
	WORK="$(CURDIR)/work/$$stem"; \
	case "$$asm" in /*) SRC=$$asm;; *) SRC="$(CURDIR)/$$asm";; esac; \
	echo "+ BUILD_DIR=$$WORK  $(TOOLCHAIN_SH) $$SRC"; \
	mkdir -p "$$WORK"; \
	BUILD_DIR="$$WORK" MAX_CYCLES="$${MAX_CYCLES:-5000}" RUN_FSDB="$${RUN_FSDB:-0}" \
	  RV32M_WAVE_VCD="$(RV32M_WAVE_VCD)" RV32M_VCS_KDB="$(RV32M_VCS_KDB)" \
	  "$(TOOLCHAIN_SH)" "$$SRC"