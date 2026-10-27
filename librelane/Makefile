# open_rv32m — LibreLane synthesis on IHP SG13G2 (open-source counterpart of dc/)
# Runs Yosys synthesis + OpenROAD pre-PnR STA inside the LibreLane Docker image.
#   make -C librelane
#   make -C librelane CLOCK_PERIOD=10 TAG=p10

.DEFAULT_GOAL := synth

LL_DIR         := $(abspath $(CURDIR))
LIBRELANE_VENV ?= $(HOME)/.venv/librelane
PDK_ROOT       ?= $(HOME)/.ciel
PDK            := ihp-sg13g2
TAG            ?= synth
CLOCK_PERIOD   ?=
# Extra LibreLane arguments, e.g. LL_ARGS='-c SYNTH_STRATEGY="DELAY 1"'
LL_ARGS        ?=

LIBRELANE := $(LIBRELANE_VENV)/bin/python -m librelane --docker-no-tty --dockerized
RUN_DIR   := $(LL_DIR)/runs/$(TAG)

export PDK_ROOT

.PHONY: help synth qor check-env clean

help:
	@echo "open_rv32m IHP SG13G2 synthesis (LibreLane)"
	@echo ""
	@echo "  make synth      Yosys synthesis + pre-PnR STA (default)"
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
	cd "$(LL_DIR)" && $(LIBRELANE) --pdk $(PDK) config.yaml \
		--to OpenROAD.STAPrePNR --run-tag $(TAG) --overwrite \
		$(if $(CLOCK_PERIOD),-c CLOCK_PERIOD=$(CLOCK_PERIOD)) $(LL_ARGS)
	@$(MAKE) --no-print-directory qor TAG=$(TAG)

qor:
	@python3 "$(LL_DIR)/qor.py" "$(RUN_DIR)"

clean:
	rm -rf "$(LL_DIR)/runs"
