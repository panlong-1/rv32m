# rv32m

Open-source **RV32I + M-extension** five-stage in-order core and the **TORV** SoC
(**T**orino **O**pen **R**ISC-**V**), with a fully open-source flow from RTL to GDS:

- **Simulation:** Verilator + GTKWave, directed RISC-V assembly tests, self-checking
  testbench, regression and performance counters.
- **Physical implementation:** LibreLane (Yosys, OpenROAD, Magic, KLayout, Netgen) on the
  **IHP SG13G2** 130 nm open PDK, including the IHP SRAM macros.

No commercial EDA tool or proprietary PDK is needed. Step-by-step instructions are in
[docs/open_source_flow.md](docs/open_source_flow.md).

## Highlights

- **ISA:** RV32I (no CSRs, traps or C extension) + RV32M.
  - `MUL*`: two cycles (operand register + Booth multiplier).
  - `DIV`/`REM*`: iterative restoring divider (≈34 cycles); divide-by-zero and
    overflow results per the RISC-V spec.
- **Pipeline:** IF / ID / EX / MEM / WB with:
  - EX/MEM and MEM/WB forwarding (registered selects);
  - load-use bubble;
  - branches resolved in EX (2-cycle taken penalty);
  - a dedicated AGU for load/store addresses.
- **Buses:** Harvard core with three **pipelined AHB-Lite** masters:
  - **IBUS** — one fetch per cycle;
  - **DBUS / SBUS** — address phase in EX, data phase in MEM, so loads and stores to a
    zero-wait slave never stall.
- **TORV SoC (`torv_soc_top`):**
  - three IHP SG13G2 SRAM macros, 4 KiB each by default, behind the zero-wait wrapper
    `torv_ahb_sram`;
  - SoCBUS `AHB_APB_BRIDGE` and the PULP `apb_uart_sv` UART.
  - Address map: [docs/torv_address_map.md](docs/torv_address_map.md).
- **Verification:**
  - 33-case regression (`regress/cases/soc.list`) with pass/fail via a `tohost` store;
  - `[PERF]` counters per case and `perf_summary.csv` per run;
  - PC/WB trace checks for hazard cases.
- **Implementation:** `rv32im_ahb_top` closes DRC, LVS and antenna checks at 10 ns
  (results below).

## Repository layout

| Path | Contents |
|------|----------|
| `rtl/` | Core (`rv32im_core` and its units), AHB masters (`rv32im_ahb_fetch`, `rv32im_ahb_dport`), `rv32im_ahb_top`, SoC (`torv_soc_top`, `torv_ahb_sram`), `filelist.f` |
| `sim/` | Testbench `tb_torv_soc.sv`, `Makefile` shortcuts, [SIM_README.md](sim/SIM_README.md) |
| `tests/core/asm/` | Directed assembly tests, `link.ld`, per-case `.plusargs` |
| `tests/periph/` | Peripheral tests (UART) |
| `regress/` | Regression driver and case lists ([README](regress/README.md)) |
| `scripts/` | `open_rv.sh` environment, `run_case.sh`, `regress.sh`, Verilator build, waveform/trace/perf helpers |
| `ip/` | Third-party IP filelist; sources are fetched into `ip/third_party/` ([README](ip/README.md)) |
| `librelane/` | LibreLane config, SDC, `Makefile` (`synth`, `flow`), `qor.py` |
| `spec/` | [RV32IM_Current_Implementation.md](spec/RV32IM_Current_Implementation.md) — microarchitecture reference |
| `docs/` | Open-source flow, address map, loading, TODO, changelog, bug notes |

## Prerequisites

The versions below are tested (Ubuntu 24.04, also under WSL2):

| Tool | Version | Used for |
|------|---------|----------|
| Verilator | 5.020 (≥ 5.0 with `--timing`) | Simulation |
| `gcc-riscv64-unknown-elf` | 13.2 | Assembling tests (`-march=rv32im -mabi=ilp32`) |
| GTKWave | 3.3 | Waveforms (optional) |
| Python 3, `curl`, `make`, `g++` | — | Scripts, IP fetch, Verilator C++ build |
| IHP SG13G2 PDK | via `ciel` (LibreLane) | SRAM simulation models, implementation |
| LibreLane | 3.0.16 (Python venv + Docker) | Synthesis, place & route, signoff (optional) |

Ubuntu packages:

```bash
sudo apt install verilator gcc-riscv64-unknown-elf gtkwave python3 python3-venv make g++ curl
```

The IHP PDK is needed **for simulation as well**, because the SoC SRAMs use the PDK's
`RM_IHPSG13_1P_*` functional models. Install LibreLane and the PDK as described in
[docs/open_source_flow.md](docs/open_source_flow.md#1-install-the-tools). The default
`PDK_ROOT` is `~/.ciel`.

## Quick start

```bash
git clone https://github.com/panlong-1/rv32m.git
cd rv32m
source scripts/open_rv.sh                        # paths, PATH, PDK_ROOT; prints what it found

./scripts/run_case.sh tests/core/asm/smoke.S     # one test (fetches third-party IP on first run)
./scripts/regress.sh                             # full regression: 33 cases

./scripts/run_case.sh --vcd tests/core/asm/smoke.S
./scripts/open_gtkwave.sh smoke                  # waves

make -C librelane                                # IHP synthesis + pre-PnR STA (minutes)
make -C librelane flow                           # full RTL-to-GDS + signoff (~1-1.5 h)
```

## Environment

`scripts/open_rv.sh` is the single place for paths. It:

- sets `RV32M_ROOT`, `PROJECT_ROOT` (the repo's parent) and `PDK_ROOT`;
- picks the RISC-V toolchain: `$PROJECT_ROOT/riscv_toolchain/bin` if present, otherwise
  `/usr/bin`;
- puts `scripts/` and the toolchain on `PATH`.

After a case runs, `t` changes directory to its build folder. `source regress/env.sh` does
the same setup from anywhere in the tree.

| Variable | Default | Purpose |
|----------|---------|---------|
| `RV32M_RISCV_TOOLCHAIN_BIN` | `$PROJECT_ROOT/riscv_toolchain/bin` or `/usr/bin` | Directory holding `${PREFIX}gcc` |
| `RV32M_RISCV_GNU_PREFIX` | `riscv64-unknown-elf-` | Toolchain prefix |
| `RV32M_VERILATOR` / `RV32M_VERILATOR_BIN_DIR` | `verilator` / — | Verilator binary / extra `PATH` entry |
| `RV32M_GTKWAVE` | `gtkwave` | GTKWave binary |
| `PDK_ROOT` | `~/.ciel` | IHP SG13G2 PDK (SRAM models, LibreLane) |
| `LIBRELANE_VENV` | `~/.venv/librelane` | LibreLane Python venv |

To override paths without editing tracked files, copy `scripts/open_rv.local.sh.example` to
`scripts/open_rv.local.sh`. That copy is gitignored and is sourced after the defaults.

## Simulation

```bash
./scripts/run_case.sh tests/core/asm/loadstore.S               # one case → build/sim/soc/loadstore/
./scripts/run_case.sh --vcd tests/core/asm/hazard.S            # + hazard.vcd
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S        # + pc_trace.tsv (PC and WB columns)
./scripts/run_case.sh --max-cycles 50000 tests/core/asm/muldiv.S
RV32M_KEEP_BUILD=1 ./scripts/run_case.sh tests/core/asm/smoke.S   # keep the existing build dir
```

- Each case directory holds the ELF, HEX, disassembly (`.dump`), `<case>.sim.log`, the
  Verilator build (`verilator/obj_dir`) and an optional VCD / PC trace.
- Tests end by storing to `tohost` at `0xF000_0000`: `1` means PASS, anything else FAIL.
  `max_cycles` is only a watchdog.
- `sim/Makefile` offers the same commands as shortcuts, e.g. `make -C sim run CASE=smoke VCD=1`,
  `make -C sim regress`, `make -C sim gtkwave CASE=smoke`.

Details: [sim/SIM_README.md](sim/SIM_README.md), [docs/loading.md](docs/loading.md),
[tests/core/README.md](tests/core/README.md).

## Regression and performance

```bash
./scripts/regress.sh                                        # regress/cases/soc.list (33 cases)
./scripts/regress.sh --case alu --case muldiv
./scripts/regress.sh --case-list regress/cases/deep_hazard.list
./scripts/regress.sh --waves --pc-trace
./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup --run
./scripts/perf_summary.py regress/results/<stamp> --csv perf.csv
```

Results go to `regress/results/<stamp>/`:
- `summary.rpt`;
- per-case directories;
- `perf_summary.csv`, with cycles, instructions, IPC, instruction mix, stall/flush counts and
  bus transfers.

Representative cycle counts (v0.6):

| Case | Cycles | IPC |
|------|--------|-----|
| `perf_alu_chain` | 777 | 0.835 |
| `perf_loadstore_loop` | 330 | 0.709 |
| `perf_branch_loop` | 648 | 0.605 |
| `perf_mul_loop` | 122 | 0.607 |

## Physical implementation (IHP SG13G2, LibreLane)

The implemented block is `rv32im_ahb_top`: the core plus its three AHB-Lite masters. The SoC
SRAM macros and peripherals are not part of this block.

- Configuration: [librelane/config.yaml](librelane/config.yaml).
  - Synthesis: slang frontend, ABC buffering, Booth multiplier.
  - Implementation: post-global-route timing repair.
  - Clock period: 10 ns.
- Constraints: [librelane/constraints.sdc](librelane/constraints.sdc) — 2 ns input/output
  delay budget, 0.3 ns setup uncertainty.

```bash
make -C librelane                       # synth + pre-PnR STA → runs/synth
make -C librelane flow                  # full flow → runs/flow (GDS, signoff)
make -C librelane flow CLOCK_PERIOD=12.5 TAG=p12
make -C librelane qor TAG=flow          # re-print a run's QoR
```

Full-flow results at 10 ns (v0.6):

| Metric | Value |
|--------|-------|
| Std-cell area / die area | 266.7k µm² / 0.508 mm² (56% utilization) |
| Setup WNS — typ 1.20 V / 25 °C | +2.35 ns |
| Setup WNS — fast 1.32 V / −40 °C | +4.12 ns |
| Setup WNS — slow 1.08 V / 125 °C | **−0.73 ns** (26 endpoints, mostly register → AHB address/control outputs) |
| Hold | met at all corners |
| Magic / KLayout DRC, Netgen LVS, antenna | clean |

At the slow corner the block runs at about 93 MHz under the 2 ns output-delay budget. The
remaining paths and options to close them are listed in [docs/TODO_LIST.md](docs/TODO_LIST.md).

## Version history

Each step is a tag on the main branch. `git checkout <tag>` or `git diff <tag-a> <tag-b>` shows
the exact change.

| Tag | Change |
|-----|--------|
| `v0.1-baseline` | Baseline before bus pipelining and the IHP flow (IPC ≈ 0.2) |
| `v0.2-ibus-pipe` | Pipelined AHB-Lite instruction fetch (IPC up to ≈ 0.8) |
| `v0.3-dbus-pipe` | Pipelined DBUS/SBUS: zero-wait loads and stores |
| `v0.4-ihp-sram` | SoC memories on IHP SG13G2 SRAM macros (zero-wait wrapper) |
| `v0.5-timing` | Slow-corner timing: AGU, two-cycle MUL, Booth, post-GRT repair |
| `v0.6-fwd-reg` | Registered forwarding selects, pre-selected MEM/WB result |
| `v0.7-open-flow` | Open-source-only repository, `make -C librelane flow`, documentation refresh |

`docs/changelog/` contains the session notes.

## Documentation

- [docs/open_source_flow.md](docs/open_source_flow.md) — install the tools; simulation →
  regression → synthesis → RTL-to-GDS → viewing results.
- [spec/RV32IM_Current_Implementation.md](spec/RV32IM_Current_Implementation.md) —
  microarchitecture (pipeline, hazards, buses, SoC).
- [docs/torv_address_map.md](docs/torv_address_map.md) — address map.
- [rtl/TORV.md](rtl/TORV.md) — SoC overview.
- [sim/SIM_README.md](sim/SIM_README.md) — simulation reference.
- [regress/README.md](regress/README.md) — regression.
- [docs/loading.md](docs/loading.md) — program loading.
- [tests/core/README.md](tests/core/README.md), [tests/periph/README.md](tests/periph/README.md) — tests.
- [ip/README.md](ip/README.md) — third-party IP.
- [docs/TODO_LIST.md](docs/TODO_LIST.md) — open items.

## License

[MIT](LICENSE). Third-party IP fetched into `ip/third_party/` keeps its own license
([ip/README.md](ip/README.md)).
