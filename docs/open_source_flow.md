# Open-source flow: RTL → simulation → GDS

This guide takes rv32m from a fresh Linux machine to a regression run and a signed-off GDS of
`rv32im_ahb_top` on IHP SG13G2. Every tool in it is open source.

```text
 tests/*.S ──gcc──> .elf/.hex ──┐
                                ├─> Verilator (tb_torv_soc + torv_soc_top + IHP SRAM models)
 rtl/*.sv + ip/ + PDK models ───┘        └─> [PASS]/[FAIL], [PERF], VCD (GTKWave), PC trace

 rtl/ (rv32im_ahb_top) ──LibreLane──> Yosys ─> OpenROAD (floorplan, place, CTS, route, RCX, STA)
                                     ─> Magic / KLayout (GDS, DRC) ─> Netgen (LVS) ─> GDS
```

| Step | Tool | Command |
|------|------|---------|
| Environment | bash | `source scripts/open_rv.sh` |
| Single test | GNU toolchain + Verilator | `./scripts/run_case.sh tests/core/asm/smoke.S` |
| Waves | GTKWave | `./scripts/run_case.sh --vcd …` then `./scripts/open_gtkwave.sh <case>` |
| Regression | Python + Verilator | `./scripts/regress.sh` |
| Synthesis + STA | LibreLane (Yosys, OpenROAD) | `make -C librelane` |
| RTL-to-GDS + signoff | LibreLane (OpenROAD, Magic, KLayout, Netgen) | `make -C librelane flow` |
| Layout view | KLayout | `klayout -l $PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/sg13g2.lyp runs/flow/final/gds/rv32im_ahb_top.gds` |

## 1. Install the tools

Tested on Ubuntu 24.04 (native and WSL2). On WSL, keep the repository on the Linux file system
(`~/…`), not under `/mnt/c`. The LibreLane Docker container only mounts paths under `$HOME`,
and builds are much faster there.

### 1.1 Simulation tools

```bash
sudo apt update
sudo apt install verilator gcc-riscv64-unknown-elf gtkwave \
                 python3 python3-venv python3-pip make g++ curl git
verilator --version                      # 5.020 tested; needs >= 5.0 (--timing)
riscv64-unknown-elf-gcc --version        # 13.2 tested
```

A different toolchain prefix or location also works. Set `RV32M_RISCV_TOOLCHAIN_BIN` and
`RV32M_RISCV_GNU_PREFIX` (see `scripts/open_rv.local.sh.example`).

### 1.2 Docker (for LibreLane)

```bash
sudo apt install docker.io
sudo usermod -aG docker "$USER"          # log out and back in (WSL: wsl --shutdown)
docker run --rm hello-world
```

### 1.3 LibreLane and the IHP SG13G2 PDK

```bash
python3 -m venv ~/.venv/librelane
~/.venv/librelane/bin/pip install librelane==3.0.16
docker pull ghcr.io/librelane/librelane:3.0.16           # ~7.5 GB

# PDK revision pinned by LibreLane 3.0.16 (librelane/pdk_hashes.yaml)
~/.venv/librelane/bin/ciel enable --pdk-family ihp-sg13g2 c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c
ls ~/.ciel/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/     # RM_IHPSG13_1P_*.v
```

`ciel` installs into `~/.ciel`, the default `PDK_ROOT`. The first LibreLane run would also
fetch the PDK automatically. Simulation needs it earlier, though, because the SoC SRAMs are the
PDK's `RM_IHPSG13_1P_*` macros. Enable it before the first `run_case.sh`.

### 1.4 Optional: KLayout

```bash
sudo apt install klayout
```

KLayout is only for viewing the GDS on the host. DRC and LVS run inside the LibreLane container.

## 2. Environment

```bash
git clone https://github.com/panlong-1/rv32m.git ~/project/rv32m
cd ~/project/rv32m
source scripts/open_rv.sh
```

`open_rv.sh` prints what it found. Every line should resolve:

```text
  RV32M_RISCV_TOOLCHAIN_BIN=/usr/bin
  RV32M_VERILATOR=verilator (/usr/bin/verilator)
  RV32M_GTKWAVE=gtkwave (/usr/bin/gtkwave)
  PDK_ROOT=/home/<you>/.ciel (IHP SRAM models: ok)
  LIBRELANE_VENV=/home/<you>/.venv/librelane (ok; only needed for make -C librelane)
```

To change a path without editing tracked files, copy `scripts/open_rv.local.sh.example` to
`scripts/open_rv.local.sh`.

## 3. Simulation

```bash
./scripts/run_case.sh tests/core/asm/smoke.S
```

What happens (`scripts/internal/run_soc_sim.sh`):

1. On the first run, `scripts/fetch_ip.sh` downloads SoCBUS (`AHB_APB_BRIDGE`) and the PULP
   `apb_uart_sv` into `ip/third_party/`, with small Verilator compatibility patches.
2. `riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32` with `tests/core/link.ld` builds the ELF.
   `objcopy -O verilog` turns it into a HEX image.
3. `scripts/verilator_build.sh` compiles `rtl/filelist.f` (RTL and the IHP SRAM models),
   `ip/filelist.f` and `sim/tb_torv_soc.sv` with
   `verilator --binary --timing -DFUNCTIONAL`.
4. The testbench loads the image into the instruction SRAM and releases reset. The program ends
   by storing `1` (PASS) or another value (FAIL) to `0xF000_0000`.

Outputs are in `build/sim/soc/smoke/`: `smoke.sim.log` with `[PERF]` and `[PASS] TORV`, the ELF,
HEX and disassembly, and the Verilator build.

Debugging:

```bash
./scripts/run_case.sh --vcd tests/core/asm/hazard.S && ./scripts/open_gtkwave.sh hazard
./scripts/run_case.sh --pc-trace tests/core/asm/hazard.S     # build/sim/soc/hazard/pc_trace.tsv
t                                                             # cd into the last case directory
```

More: [sim/SIM_README.md](../sim/SIM_README.md).

## 4. Regression

```bash
./scripts/regress.sh                     # 33 cases, ~2-3 min
cat regress/results/<stamp>/summary.rpt
./scripts/perf_summary.py regress/results/<stamp>
./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup --run
./scripts/check_hazard_dup_trace.py --case hazard_ibus_load_dup --run
```

All 33 cases must pass before RTL changes go to `main`. When a change alters cycle counts, give
the reason in the commit message (compare the two runs' `perf_summary.csv`). More:
[regress/README.md](../regress/README.md).

## 5. Synthesis and pre-PnR timing

```bash
make -C librelane check-env              # venv, PDK, docker
make -C librelane                        # -> librelane/runs/synth, prints QoR
make -C librelane synth CLOCK_PERIOD=7 TAG=p7     # other clock, separate run directory
```

Inputs:

- [librelane/config.yaml](../librelane/config.yaml):
  - design `rv32im_ahb_top` with its RTL list;
  - slang SystemVerilog frontend, `SYNTH_ABC_BUFFERING`, `SYNTH_MUL_BOOTH`;
  - `RUN_POST_GRT_RESIZER_TIMING`;
  - `CLOCK_PERIOD: 10.0`.
- [librelane/constraints.sdc](../librelane/constraints.sdc): clock `CLK` on `hclk`, 2 ns
  input/output delay, 0.05 pF output load, 0.3 / 0.1 ns setup/hold uncertainty, false path from
  `hresetn`.

This runs the steps up to `OpenROAD.STAPrePNR` (a few minutes). Pre-PnR STA has no placement
or wires, so it is optimistic. In this design the final slow-corner slack came out 0.8–2.5 ns
worse than the pre-PnR estimate. Use it to compare RTL variants, not as a signoff number.

Useful outputs in `librelane/runs/<tag>/`:

- `final/nl/rv32im_ahb_top.nl.v` — mapped netlist
- `06-yosys-synthesis/reports/stat.rpt` — cell report
- `*-openroad-staprepnr/<corner>/max.rpt`, `violator_list.rpt` — timing per corner
  (`nom_slow_1p08V_125C`, `nom_typ_1p20V_25C`, `nom_fast_1p32V_m40C`)

## 6. RTL-to-GDS and signoff

```bash
make -C librelane flow                   # -> librelane/runs/flow, ~1-1.5 h on a laptop
make -C librelane qor TAG=flow
```

The LibreLane Classic flow (about 78 steps) runs:

1. Lint (Verilator) and synthesis (Yosys).
2. Floorplan (`FP_CORE_UTIL` 50%), tap/endcap cells, PDN.
3. Global placement, I/O placement, design repair, detailed placement.
4. CTS, then post-CTS setup/hold repair.
5. Global routing, post-global-route repair (`RUN_POST_GRT_RESIZER_TIMING`), antenna
   diodes / repair.
6. Detailed routing, fill insertion.
7. RC extraction, then multi-corner STA (`*-openroad-stapostpnr`) and IR drop.
8. GDS streamout with Magic and KLayout, then XOR between the two.
9. Signoff: Magic and KLayout DRC, Netgen LVS, antenna check, then `manufacturability.rpt`.

Check these after a run:

| What | Where | Expected |
|------|-------|----------|
| Summary | `make -C librelane qor TAG=flow` | — |
| DRC / LVS / antenna | `runs/flow/*-misc-reportmanufacturability/manufacturability.rpt` | all "Passed" |
| Timing | `runs/flow/*-openroad-stapostpnr/<corner>/violator_list.rpt`, `max.rpt`, `min.rpt` | hold met; setup see below |
| Layout | `runs/flow/final/gds/rv32im_ahb_top.gds`, picture `final/render/rv32im_ahb_top.png` | — |
| Abstracts | `final/lef/`, `final/lib/<corner>/`, `final/sdf/`, `final/spef/` | for integration in a larger chip |

Results at 10 ns (v0.6 RTL, run `full_p10_fwd`):

| Metric | Value |
|--------|-------|
| Std-cell area / die | 266.7k µm² / 0.508 mm² (56% utilization) |
| Setup WNS typ / fast / slow | +2.35 / +4.12 / **−0.73 ns** (26 endpoints at the slow corner) |
| Hold WNS | +0.10 ns (fast corner); no violations |
| Magic DRC, KLayout DRC, LVS, antenna | 0 / 0 / 0 / 0 |
| Power (default activity) | ≈ 14 mW |

The remaining slow-corner violations come from forwarding → branch target / AGU → AHB
address/control outputs, under the generic 2 ns output budget. Options are in
[TODO_LIST.md](TODO_LIST.md). LibreLane reports a "setup violations" warning for the slow
corner. That is expected until those paths are closed.

To view the layout:

```bash
klayout -l $PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/sg13g2.lyp \
        librelane/runs/flow/final/gds/rv32im_ahb_top.gds
```

To regenerate the README figures from a full run:

```bash
make -C librelane figures                      # from runs/flow
make -C librelane figures TAG=full_p10_fwd \
    HIST="v0.4=runs/full_p10 v0.5=runs/full_p10_booth v0.6=runs/full_p10_fwd"
```

This writes the following to `docs/img/`:

| File | Content | Made by |
|------|---------|---------|
| `layout_full.png` | Whole layout | KLayout, run in the LibreLane image |
| `layout_zoom.png` | 24 × 16 µm window at the die centre | KLayout, run in the LibreLane image |
| `placement_modules.svg` | Cells coloured by RTL module | `figures/placement_map.py`, from the DEF |
| `timing_area.svg` | Slow-corner WNS and area for each run in `HIST` | `figures/qor_charts.py`, from `metrics.json` |
| `area_breakdown.svg` | Area by cell class | `figures/qor_charts.py`, from `metrics.json` |

The architecture diagrams (`soc_arch.svg`, `pipeline.svg`) are drawn by hand.

## 7. Changing the design

Typical loop for an RTL change:

1. Edit `rtl/`. When you add a file, also add it to `rtl/filelist.f` (simulation) and
   `librelane/config.yaml` `VERILOG_FILES` (implementation).
2. Run `./scripts/regress.sh`: 33/33 must pass. Check `perf_summary.csv` for cycle changes.
3. Run `make -C librelane synth TAG=<name>` and compare QoR with the previous run.
4. Run `make -C librelane flow TAG=<name>` for final timing and signoff.
5. Commit with the regression and QoR numbers in the message, and tag milestones (`vX.Y-…`).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `IHP SRAM models: MISSING` | `ciel enable --pdk-family ihp-sg13g2 <hash>` (§1.3) or set `PDK_ROOT` |
| `docker is not usable by $USER` | add yourself to the `docker` group and log in again |
| LibreLane cannot find files | keep the repository under `$HOME` (the container mounts only that) |
| WSL run stops halfway | WSL was shut down (idle timeout or `wsl --shutdown`). Rerun; `--overwrite` restarts the tag |
| Verilator C++ errors | Verilator ≥ 5.0 and a C++17 `g++` are required; see `build/sim/soc/<case>/verilator/verilator.log` |
