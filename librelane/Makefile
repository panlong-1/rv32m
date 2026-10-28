# open_rv32m — LibreLane (Yosys + OpenROAD + Magic/KLayout/Netgen) on IHP SG13G2.
# Runs inside the LibreLane Docker image.
#   make -C librelane                      # synthesis + pre-PnR STA (minutes)
#   make -C librelane flow                 # full RTL-to-GDS + signoff (~1-1.5 h)
#   make -C librelane synth CLOCK_PERIOD=7 TAG=p7

.DEFAULT_GOAL := synth

LL_DIR         := $(abspath $(CURDIR))
LIBRELANE_VENV ?= $(HOME)/.venv/librelane
PDK_ROOT       ?= $(HOME)/.ciel
PDK            := ihp-sg13g2
# Run tag (runs/<TAG>): "flow" for make flow, otherwise "synth"
TAG            ?= $(if $(filter flow,$(MAKECMDGOALS)),flow,synth)
# Override the config.yaml clock period (ns)
CLOCK_PERIOD   ?=
# Extra LibreLane arguments, e.g. LL_ARGS='-c SYNTH_STRATEGY="DELAY 1"'
LL_ARGS        ?=

LIBRELANE := $(LIBRELANE_VENV)/bin/python -m librelane --docker-no-tty --dockerized
RUN_DIR   := $(LL_DIR)/runs/$(TAG)
RUN_ARGS   = --pdk $(PDK) config.yaml --run-tag $(TAG) --overwrite \
             $(if $(CLOCK_PERIOD),-c CLOCK_PERIOD=$(CLOCK_PERIOD)) $(LL_ARGS)

export PDK_ROOT

.PHONY: help synth flow qor check-env clean

help:
	@echo "open_rv32m on IHP SG13G2 (LibreLane)"
	@echo ""
	@echo "  make synth      Yosys synthesis + pre-PnR STA (default)"
	@echo "  make flow       Full RTL-to-GDS: floorplan, PnR, CTS, routing, RCX,"
	@echo "                  multi-corner STA, Magic/KLayout DRC, Netgen LVS, antenna"
	@echo "  make qor        Print QoR of runs/\$$TAG"
	@echo "  make check-env  Verify LibreLane venv, PDK and Docker"
	@echo "  make clean      Remove runs/"
	@echo ""
	@echo "Variables: TAG=$(TAG) CLOCK_PERIOD=<ns> LIBRELANE_VENV=$(LIBRELANE_VENV) PDK_ROOT=$(PDK_ROOT) LL_ARGS=..."

check-env:
	@test -x "$(LIBRELANE_VENV)/bin/python" || \
		( echo "ERROR: no LibreLane venv at $(LIBRELANE_VENV) (set LIBRELANE_VENV)"; exit 1 )
	@test -d "$(PDK_ROOT)/$(PDK)" || \
		( echo "ERROR: $(PDK) not found under PDK_ROOT=$(PDK_ROOT)"; exit 1 )
	@docker info >/dev/null 2>&1 || ( echo "ERROR: docker is not usable by $$USER"; exit 1 )

synth: check-env
	cd "$(LL_DIR)" && $(LIBRELANE) $(RUN_ARGS) --to OpenROAD.STAPrePNR
	@$(MAKE) --no-print-directory qor TAG=$(TAG)

flow: check-env
	cd "$(LL_DIR)" && $(LIBRELANE) $(RUN_ARGS)
	@$(MAKE) --no-print-directory qor TAG=$(TAG)

qor:
	@python3 "$(LL_DIR)/qor.py" "$(RUN_DIR)"

clean:
	rm -rf "$(LL_DIR)/runs"
