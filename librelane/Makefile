# TORV — LibreLane (Yosys + OpenROAD + Magic/KLayout/Netgen) on IHP SG13G2.
# Runs inside the LibreLane Docker image.
#   make -C librelane                      # synthesis + pre-PnR STA (minutes)
#   make -C librelane flow                 # full RTL-to-GDS + signoff (~1-1.5 h)
#   make -C librelane synth CLOCK_PERIOD=7 TAG=p7
#   make -C librelane figures              # layout PNGs + QoR SVGs of runs/flow -> docs/img

SHELL := /bin/bash
.DEFAULT_GOAL := synth

LL_DIR         := $(abspath $(CURDIR))
LIBRELANE_VENV ?= $(HOME)/.venv/librelane
PDK_ROOT       ?= $(HOME)/.ciel
PDK            := ihp-sg13g2
# Top module, read from config.yaml (DESIGN_NAME)
DESIGN         := $(shell awk '/^DESIGN_NAME:/{print $$2}' $(LL_DIR)/config.yaml)
# Run tag (runs/<TAG>): "flow" for make flow / figures, otherwise "synth"
TAG            ?= $(if $(filter flow figures,$(MAKECMDGOALS)),flow,synth)
# Override the config.yaml clock period (ns)
CLOCK_PERIOD   ?=
# Extra LibreLane arguments, e.g. LL_ARGS='-c SYNTH_STRATEGY="DELAY 1"'
LL_ARGS        ?=
# make figures: output directory, LibreLane image (for KLayout), and optional run history
# for the timing/area chart as LABEL=RUN_DIR pairs (default: just runs/<TAG>)
FIG_DIR        ?= $(abspath $(LL_DIR)/../docs/img)
LL_IMAGE       ?= ghcr.io/librelane/librelane:3.0.16
HIST           ?=

LIBRELANE := $(LIBRELANE_VENV)/bin/python -m librelane --docker-no-tty --dockerized
RUN_DIR   := $(LL_DIR)/runs/$(TAG)
RUN_ARGS   = --pdk $(PDK) config.yaml --run-tag $(TAG) --overwrite \
             $(if $(CLOCK_PERIOD),-c CLOCK_PERIOD=$(CLOCK_PERIOD)) $(LL_ARGS)

export PDK_ROOT

.PHONY: help synth flow qor figures check-env clean

help:
	@echo "TORV on IHP SG13G2 (LibreLane)"
	@echo ""
	@echo "  make synth      Yosys synthesis + pre-PnR STA (default)"
	@echo "  make flow       Full RTL-to-GDS: floorplan, PnR, CTS, routing, RCX,"
	@echo "                  multi-corner STA, Magic/KLayout DRC, Netgen LVS, antenna"
	@echo "  make qor        Print QoR of runs/\$$TAG"
	@echo "  make figures    Layout renders, placement map and QoR charts of a full"
	@echo "                  run (TAG=flow) into FIG_DIR=docs/img"
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

figures:
	@test -f "$(RUN_DIR)/final/gds/$(DESIGN).gds" || \
		( echo "ERROR: $(RUN_DIR) has no final GDS; run make flow first"; exit 1 )
	mkdir -p "$(FIG_DIR)"
	python3 figures/placement_map.py "$(RUN_DIR)/final/def/$(DESIGN).def" "$(FIG_DIR)/placement_modules.svg"
	python3 figures/qor_charts.py "$(FIG_DIR)" $(if $(HIST),$(HIST),$(TAG)=$(RUN_DIR))
	@set -e; \
	read X1 Y1 X2 Y2 < <(python3 -c "import json; print(json.load(open('$(RUN_DIR)/final/metrics.json'))['design__die__bbox'])"); \
	LYP=$$(python3 -c "import json; print(json.load(open('$(RUN_DIR)/resolved.json'))['KLAYOUT_PROPERTIES'])"); \
	CX=$$(python3 -c "print(($$X1+$$X2)/2)"); CY=$$(python3 -c "print(($$Y1+$$Y2)/2)"); \
	render() { docker run --rm -u $$(id -u):$$(id -g) -v "$(PDK_ROOT)":"$(PDK_ROOT)" \
		-v "$$(readlink -f $(PDK_ROOT))":"$$(readlink -f $(PDK_ROOT))" -v "$(LL_DIR)":"$(LL_DIR)" -v "$(FIG_DIR)":"$(FIG_DIR)" \
		$(LL_IMAGE) klayout -zz -rd gds="$(RUN_DIR)/final/gds/$(DESIGN).gds" -rd lyp="$$LYP" \
		-rd out="$(FIG_DIR)/$$1" -rd box="$$2" -rd w="$$3" -r "$(LL_DIR)/figures/render_gds.py"; }; \
	render layout_full.png "$$X1,$$Y1,$$X2,$$Y2" 900; \
	render layout_zoom.png "$$(python3 -c "print(f'{$$CX-12},{$$CY-8},{$$CX+12},{$$CY+8}')")" 1000; \
	echo "figures written to $(FIG_DIR)"

clean:
	rm -rf "$(LL_DIR)/runs"
