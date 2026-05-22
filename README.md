# rv32m

Open-source **RV32I + M-extension** five-stage in-order Harvard core (no CSRs/traps/C extension). Verilator-first simulation with directed asm tests, regression automation, and optional Synopsys VCS/Verdi/DC. Waveforms: **VCD + GTKWave**; FSDB when using VCS.

## Highlights

- **ISA:** RV32I subset + RV32M (`MUL*` single-cycle; `DIV`/`REM*` multi-cycle).
- **Pipeline:** IF / ID / EX / MEM / WB.
- **SoC:** **TORV** (**T**orino **O**pen **R**ISC-**V**) — `torv_soc_top` integrates CPU, AHB SRAM, SoCBUS `AHB_APB_BRIDGE`, PULP UART.
- **Buses:** Harvard inside the core; SoC exposes three **AHB-Lite** masters.
- **Simulation:** **Verilator** (default); **VCS** via `RV32M_SIMULATOR=vcs` or `./scripts/run_case.sh --sim vcs`.
- **Waves:** VCD from Verilator/VCS; open with **GTKWave** (`scripts/open_gtkwave.sh`, `make gtkwave`). FSDB only with VCS + Verdi PLI.
- **PC trace:** testbench writes `pc_trace.tsv` (no waveform parsing required).
- **Performance:** on PASS, logs `[PERF]` lines (cycles, instr, IPC, opcode mix, stalls/flushes, bus counts).
- **Regression:** default case list per target (`regress/cases/core.list` vs `ahb.list`); unified `run_case.sh` / `regress.sh`.
- **Peripherals (AHB):** third-party SoCBUS `AHB_APB_BRIDGE` + PULP `apb_uart_sv` (`ip/`, `tests/periph/<ip>/`).

## Quick start (Verilator + GTKWave)

Prerequisites: **Verilator**, **RISC-V GNU toolchain** (`riscv32-unknown-elf-gcc` or the prefix you configure), and optionally **GTKWave**.

1. Clone this repository and load the environment (see [Environment](#environment)).
2. Run a smoke test:

   ```bash
   ./scripts/run_case.sh tests/core/asm/smoke.S
   ```

3. Re-run with VCD and open waves:

   ```bash
   ./scripts/run_case.sh --vcd tests/core/asm/smoke.S
   ./scripts/open_gtkwave.sh smoke
   ```

   Or from `sim/`: `make run CASE=smoke VCD=1` then `make gtkwave CASE=smoke`.

4. Full core regression:

   ```bash
   ./scripts/regress.sh
   ```

More detail: [sim/SIM_README.md](sim/SIM_README.md), [regress/README.md](regress/README.md), [tests/core/README.md](tests/core/README.md), [tests/periph/README.md](tests/periph/README.md), [ip/README.md](ip/README.md), [spec/RV32IM_Current_Implementation.md](spec/RV32IM_Current_Implementation.md).

## Environment

The supported way to configure paths is **`scripts/open_rv.sh`**. It lives in this repo, sets **`RV32M_ROOT`** from the script location (unless you already exported it), sets **`PROJECT_ROOT`** to the parent of the repo (default place for a sibling **`riscv_toolchain`**), prepends toolchain and optional Synopsys `bin` dirs to **`PATH`**, and exports **`RV32M_FILELIST_CORE`** / **`RV32M_FILELIST_AHB`**.

```bash
cd open_rv32m
source scripts/open_rv.sh
```

After sourcing, **`scripts/` is on `PATH`**: you can run `run_case.sh`, `regress.sh`, `open_gtkwave.sh`, etc. without `./scripts/…`.

When a case finishes, run **`t`** in the same shell to **`cd` into that case’s build directory** (ELF/HEX/log/VCD, etc.). The path is stored in `$RV32M_LAST_CASE_DIR_FILE` (default `$RV32M_ROOT/.open_rv32m_last_case_build_dir`).

Edit the **Site defaults** block at the top of `scripts/open_rv.sh` for your machine (RISC-V toolchain, Verilator, Synopsys). No manual `export` is required before `source`. Optional: copy `scripts/open_rv.local.sh.example` → `scripts/open_rv.local.sh` (gitignored) to override without editing the tracked script.

| Variable | Purpose |
|----------|---------|
| `RV32M_RISCV_TOOLCHAIN_BIN` | RISC-V `gcc`/`objdump` directory |
| `RV32M_RISCV_GNU_PREFIX` | Tool prefix, e.g. `riscv64-unknown-elf-` |
| `RV32M_VERILATOR` / `RV32M_VERILATOR_BIN_DIR` | Verilator (default sim) |
| `RV32M_VCS_HOME` / `RV32M_VERDI_HOME` / `RV32M_DC_HOME` | Optional Synopsys tools |
| `RV32M_SNPSLMD_LICENSE_FILE` | Synopsys license (if needed) |

```bash
export RV32M_RISCV_TOOLCHAIN_BIN=/home/ic/project/riscv_toolchain/bin
export RV32M_VCS_HOME=/opt/synopsys/vcs/...
source scripts/open_rv.sh
```

Legacy names `TOOLCHAIN`, `PREFIX`, `VCS_HOME` are still set automatically for existing scripts.

If you keep a clone next to other projects and prefer to run **`source open_rv`** from the **parent** directory (e.g. `project/`), a thin **`open_rv`** there can forward to this script; the canonical file remains **`scripts/open_rv.sh`**.

Equivalent from anywhere inside the tree:

```bash
source regress/env.sh
```

## Switching tools

Always **`source scripts/open_rv.sh`** first so paths and `PATH` are set. Tool choice is then a mix of **environment variables** (session-wide) and **`run_case.sh` / `regress.sh` flags** (per run).

### 1. RISC-V toolchain (compile asm tests)

Set in `scripts/open_rv.local.sh` or export before `source`:

```bash
export RV32M_RISCV_TOOLCHAIN_BIN=/path/to/riscv/bin   # must contain ${PREFIX}gcc
export RV32M_RISCV_GNU_PREFIX=riscv64-unknown-elf-    # or riscv32-unknown-elf-, riscv-none-embed-
source scripts/open_rv.sh
```

Check: `command -v ${PREFIX}gcc` and `${PREFIX}gcc -march=rv32im -mabi=ilp32 --version`.

### 2. HDL simulator (Verilator vs VCS)

| Goal | One-shot (single case) | Whole shell session |
|------|------------------------|---------------------|
| **Verilator** (default, open source) | `./scripts/run_case.sh tests/core/asm/smoke.S` | `export RV32M_SIMULATOR=verilator` |
| **VCS** (Synopsys) | `./scripts/run_case.sh --sim vcs tests/core/asm/smoke.S` | `export RV32M_SIMULATOR=vcs` |

Point VCS/Verdi at your install before `source` (paths in [Environment](#environment)):

```bash
export RV32M_VCS_HOME=/opt/synopsys/vcs/...
export RV32M_VERDI_HOME=/opt/synopsys/verdi/...
export RV32M_SNPSLMD_LICENSE_FILE=27000@license-server
source scripts/open_rv.sh
```

Verilator binary search order: `RV32M_VERILATOR` → optional `RV32M_VERILATOR_BIN_DIR` on `PATH` → system `verilator`.

From `sim/Makefile`: `make run CASE=smoke SIM=verilator` or `make run CASE=smoke SIM=vcs`.

### 3. DUT target (core vs AHB)

| Target | Top module | Single case | Regression |
|--------|------------|-------------|------------|
| **soc** (default) | `torv_soc_top` / `tb_torv_soc` | `./scripts/run_case.sh tests/core/asm/smoke.S` | `./scripts/regress.sh` |

Session default: `export RV32M_TARGET=ahb` (used by `run_case.sh` when `--target` is omitted).

Makefile: `make run CASE=smoke` vs `make ahb CASE=sbus`, or `make regress TARGET=ahb`.

### 4. Waveforms and debug

| Output | Simulator | Command |
|--------|-----------|---------|
| **VCD** + GTKWave | Verilator or VCS | `./scripts/run_case.sh --vcd tests/core/asm/smoke.S` then `./scripts/open_gtkwave.sh smoke` |
| **FSDB** + Verdi | **VCS only** | `./scripts/run_case.sh --sim vcs --fsdb tests/core/asm/hazard.S` |
| **PC trace** TSV | either | `./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S` |

GTKWave: set `RV32M_GTKWAVE` if the binary is not named `gtkwave` on your `PATH`.

After a VCS run: `cd build/sim/core/<case> && ./open_verdi.sh`.

Regression with waves: `./scripts/regress.sh --waves` (VCD) or `./scripts/regress.sh --fsdb` (needs `--sim vcs` / `RV32M_SIMULATOR=vcs`).

### 5. Synthesis (Design Compiler, optional)

Not used for RTL sim. Requires `RV32M_DC_HOME` and `TSMC013_TARGET_LIB` (or your `.db`) in the environment, then:

```bash
source scripts/open_rv.sh
make -C dc
# or: ./scripts/dc_build.sh
```

### Quick reference (copy-paste)

```bash
# Open-source flow (default)
source scripts/open_rv.sh
./scripts/run_case.sh --vcd tests/core/asm/smoke.S

# VCS + FSDB + AHB
export RV32M_SIMULATOR=vcs
./scripts/run_case.sh --target ahb --fsdb tests/core/asm/sbus.S

# Custom RISC-V toolchain for one session
export RV32M_RISCV_TOOLCHAIN_BIN=$HOME/riscv/bin
export RV32M_RISCV_GNU_PREFIX=riscv64-unknown-elf-
source scripts/open_rv.sh
./scripts/regress.sh --case alu
```

| Variable / flag | Values | Effect |
|-----------------|--------|--------|
| `RV32M_RISCV_TOOLCHAIN_BIN` | path to `bin` | Asm compile |
| `RV32M_RISCV_GNU_PREFIX` | e.g. `riscv64-unknown-elf-` | Tool names |
| `RV32M_SIMULATOR` / `--sim` | `verilator`, `vcs` | Simulator |
| `RV32M_TARGET` / `--target` | `core`, `ahb` | DUT / TB |
| `--vcd` / `--waves` | flag | VCD dump |
| `--fsdb` | flag | FSDB (VCS) |
| `--pc-trace` | flag | `pc_trace.tsv` |
| `RV32M_VCS_HOME`, `RV32M_VERDI_HOME` | Synopsys roots | VCS/Verdi on `PATH` |

## Primary entry points

| Task | Command |
|------|---------|
| Single case | `./scripts/run_case.sh` |
| Regression | `./scripts/regress.sh` |

`sim/Makefile` and `tests/core/asm/Makefile` are optional shortcuts; they only invoke the same two scripts.

## Single-case simulation

```bash
# Core DUT
./scripts/run_case.sh tests/core/asm/smoke.S

# AHB top
./scripts/run_case.sh --target ahb tests/core/asm/sbus.S

# VCD (GTKWave)
./scripts/run_case.sh --vcd tests/core/asm/smoke.S
./scripts/open_gtkwave.sh smoke

# FSDB / Verdi (VCS only)
./scripts/run_case.sh --sim vcs --fsdb tests/core/asm/hazard.S
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
```

Default build layout:

```text
build/sim/core/<case>/
build/sim/ahb/<case>/
```

To keep an existing build directory instead of wiping it:

```bash
RV32M_KEEP_BUILD=1 ./scripts/run_case.sh tests/core/asm/smoke.S
```

## Optional: `sim/Makefile` shortcuts

The canonical commands are **`./scripts/run_case.sh`** and **`./scripts/regress.sh`**. From `sim/`, `make` only forwards to those scripts (same flags as environment variables):

```bash
cd sim
make run CASE=smoke
make ahb CASE=sbus
make run CASE=smoke VCD=1
make gtkwave CASE=smoke
make regress
make regress REGRESS_CASE=alu          # one case (passes --case alu)
make regress                           # TORV SoC full list
make list
make env
```

Useful variables: `TARGET=soc` (default), `CASE=<asm stem>`, `ASM=<path.S>`, `SIM=verilator|vcs`, `FSDB=1`, `VCD=1`, `TRACE=1`, `PC_TRACE=1`, `MAX_CYCLES=N`, `BUILD_DIR=...`, `REGRESS_CASE=<name>`.

`tests/core/asm/Makefile` is a tiny forwarder for **core** cases only; prefer `./scripts/run_case.sh` from the repo root.

## Regression

```bash
./scripts/regress.sh                    # TORV SoC, full list
./scripts/regress.sh --case alu
./scripts/regress.sh --waves            # VCD per case
./scripts/regress.sh --pc-trace
```

Case lists (default = `regress/cases/<target>.list`):

| Target | List | Size |
|--------|------|------|
| **soc** (default) | `regress/cases/soc.list` | **29** asm (core + `tests/periph/apb_uart_sv/*`) |

`--target core|ahb` still selects older list files but runs the same TORV SoC simulation.

Bus-overlap / replay hazard cases (sibling `tests/core/asm/<case>.plusargs`):

- `hazard_branch_mem_stall` — branch in EX while SBUS store stalls MEM
- `hazard_ibus_store_dup` — IBUS not-ready during store in MEM
- `hazard_sbus_replay_smoke` — IBUS stall during one SBUS store; non-idempotent peripheral model

Focused lists: `regress/cases/deep_hazard.list`, `regress/cases/periph_replay.list`.

Third-party IP for TORV SoC: `./scripts/fetch_ip.sh` (auto on first SoC sim). See [ip/README.md](ip/README.md), [tests/periph/README.md](tests/periph/README.md).

Performance micro-benchmarks (also in the default list): `perf_alu_chain`, `perf_branch_loop`, `perf_loadstore_loop`, `perf_mul_loop`.

## Test termination (tohost)

Assembly tests signal PASS/FAIL by writing **`0xF000_0000`**:

- `1` → PASS (`$finish` success)
- any other value → FAIL

`max_cycles` is only a watchdog.

## Outputs

Single case under `build/sim/soc/<case>/`: ELF, HEX, disassembly, log, optional VCD/FSDB, `pc_trace.tsv`, Verilator `obj_dir/` or VCS `simv`, helper `open_verdi.sh` when applicable.

Regression under `regress/results/<timestamp>/`: `summary.rpt`, per-case trees mirroring the layout above.

## Optional: Verdi

From a case directory that already ran with VCS/FSDB or VCD:

```bash
cd build/sim/soc/smoke
./open_verdi.sh
```

Filelist: use `$RV32M_FILELIST_SOC` with top `tb_torv_soc`.

## Optional: Design Compiler

```bash
make -C dc
# or: ./scripts/dc_build.sh
```

See `dc/` for logs, reports, and mapped netlist paths (ignored from git by default).

## License

[LICENSE](LICENSE) is provided as **MIT** for open redistribution. If this core is derived from or must comply with another policy at your site, replace or supplement that file accordingly.
