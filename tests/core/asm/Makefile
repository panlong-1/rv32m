# Thin wrapper — all simulation goes through scripts/run_case.sh
# Prefer (from repo root):  ./scripts/run_case.sh tests/core/asm/<case>.S

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT           := $(abspath $(MAKEFILE_DIR)/../../..)
RUN_CASE       := $(ROOT)/scripts/run_case.sh

.PHONY: help run list clean

.DEFAULT_GOAL := help

help:
	@echo "This Makefile only forwards to scripts/run_case.sh (core target)."
	@echo "From repo root (recommended):"
	@echo "  $(RUN_CASE) tests/core/asm/alu.S"
	@echo "From this directory:"
	@echo "  make run ASM=alu.S"
	@echo "  make run alu.S     # may print a harmless extra-goal line from GNU make"
	@echo "Outputs:  $(ROOT)/build/sim/core/<stem>/"

list:
	@ls -1 "$(MAKEFILE_DIR)"*.S 2>/dev/null | xargs -n1 basename | sort || true

clean:
	rm -rf "$(MAKEFILE_DIR)work" "$(ROOT)/build/sim/core"

run:
	@asm="$(ASM)"; \
	if [ -z "$$asm" ]; then asm="$(word 2,$(MAKECMDGOALS))"; fi; \
	if [ -z "$$asm" ] || [ "$$asm" = "run" ]; then \
	  echo "Usage: make run ASM=alu.S   or   make run ASM=alu   or   make run alu.S"; exit 1; \
	fi; \
	case "$$asm" in *.S);; *) if [ -f "$(CURDIR)/$$asm.S" ]; then asm="$$asm.S"; fi;; esac; \
	case "$$asm" in /*) src="$$asm";; *) src="$(CURDIR)/$$asm";; esac; \
	if [ ! -f "$$src" ]; then echo "Not found: $$src"; exit 1; fi; \
	echo "+ $(RUN_CASE) --target core $$src"; \
	exec "$(RUN_CASE)" --target core "$$src"
