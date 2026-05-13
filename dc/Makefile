# open_rv32m — Design Compiler (TSMC_013 via TSMC013_TARGET_LIB)
# Run from repo root:
#   source regress/env.sh
#   make -C dc
# Or from this directory:
#   make synth

.DEFAULT_GOAL := synth

RV32M_ROOT   := $(abspath $(CURDIR)/..)
DC_DIR       := $(abspath $(CURDIR))
DC_SHELL     ?= dc_shell-xg-t
TCL_SCRIPT   := scripts/run_dc.tcl

.PHONY: help synth dirs check-env clean distclean reports

help:
	@echo "open_rv32m Design Compiler"
	@echo ""
	@echo "  make synth      Run DC (default). Requires TSMC013_TARGET_LIB."
	@echo "  make dirs       Create logs/ outputs/ reports/ work/"
	@echo "  make check-env  Verify TSMC013_TARGET_LIB is set and exists"
	@echo "  make reports    List report files after a run"
	@echo "  make clean      Remove generated logs, work, outputs, reports"
	@echo ""
	@echo "Recommended:"
	@echo "  cd $(RV32M_ROOT) && source regress/env.sh && make -C dc"

dirs:
	mkdir -p logs outputs reports work

check-env:
	@if [ -z "$$TSMC013_TARGET_LIB" ]; then \
		echo "ERROR: TSMC013_TARGET_LIB is not set."; \
		echo "  cd $(RV32M_ROOT) && source regress/env.sh"; \
		echo "  or: export TSMC013_TARGET_LIB=/path/to/your.db"; \
		exit 1; \
	fi
	@test -f "$$TSMC013_TARGET_LIB" || \
		( echo "ERROR: TSMC013_TARGET_LIB is not a file: $$TSMC013_TARGET_LIB"; exit 1 )

synth: check-env dirs
	@echo "Using $(DC_SHELL)"
	@echo "TSMC013_TARGET_LIB=$$TSMC013_TARGET_LIB"
	cd "$(DC_DIR)" && "$(DC_SHELL)" -64 -f "$(TCL_SCRIPT)" 2>&1 | tee logs/dc.log
	@echo "Log:   $(DC_DIR)/logs/dc.log"
	@echo "QoR:   $(DC_DIR)/reports/qor.rpt"
	@echo "Netlist: $(DC_DIR)/outputs/rv32im_ahb_top_mapped.v"

reports:
	@ls -la "$(DC_DIR)/reports" 2>/dev/null || echo "No reports/ yet; run make synth first."

clean distclean:
	rm -rf "$(DC_DIR)/work" "$(DC_DIR)/outputs" "$(DC_DIR)/reports" "$(DC_DIR)/logs"
	rm -f "$(DC_DIR)/command.log" "$(DC_DIR)/filenames.log" "$(DC_DIR)/default.svf" 2>/dev/null || true
	mkdir -p "$(DC_DIR)/work" "$(DC_DIR)/outputs" "$(DC_DIR)/reports" "$(DC_DIR)/logs"
	@echo "Cleaned DC generated files under $(DC_DIR)."
