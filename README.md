# rv32m

Open-source **RV32I + M-extension** five-stage in-order Harvard core (no CSRs/traps/C extension). Verilator-first simulation with optional Synopsys VCS/Verdi/DC. with directed assembly tests, regression automation, and **Verilator** as the default simulator. Optional **Synopsys VCS / Verdi** (FSDB, KDB) and **Design Compiler** flows are supported when those tools are installed. Waveforms: **VCD + GTKWave** on any platform; FSDB when using VCS.

## Highlights

- **ISA:** RV32I subset + RV32M (`MUL*` single-cycle; `DIV`/`REM*` multi-cycle).
- **Pipeline:** IF / ID / EX / MEM / WB.
- **Buses:** Harvard `IBUS`, `DBUS`, `SBUS`; optional **AHB-Lite** wrapper (`rv32im_ahb_top`).
- **Simulation:** **Verilator** (default); **VCS** via `RV32M_SIMULATOR=vcs` or `./scripts/run_case.sh --sim vcs`.
- **Waves:** VCD from Verilator/VCS; open with **GTKWave** (`scripts/open_gtkwave.sh`, `make gtkwave`). FSDB only with VCS + Verdi PLI.
- **PC trace:** testbench writes `pc_trace.tsv` (no waveform parsing required).
- **Performance:** on PASS, logs `[PERF]` lines (cycles, instr, IPC, opcode mix, stalls/flushes, bus counts).
- **Regression:** same assembly list for core and AHB targets.

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

More detail: [sim/SIM_README.md](sim/SIM_README.md), [regress/README.md](regress/README.md), [tests/core/README.md](tests/core/README.md), [spec/RV32IM_Current_Implementation.md](spec/RV32IM_Current_Implementation.md).

## Environment

The supported way to configure paths is **`scripts/open_rv.sh`**. It lives in this repo, sets **`RV32M_ROOT`** from the script location (unless you already exported it), sets **`PROJECT_ROOT`** to the parent of the repo (default place for a sibling **`riscv_toolchain`**), prepends toolchain and optional Synopsys `bin` dirs to **`PATH`**, and exports **`RV32M_FILELIST_CORE`** / **`RV32M_FILELIST_AHB`**.

```bash
cd open_rv32m
source scripts/open_rv.sh
```

After sourcing, **`scripts/` is on `PATH`**: you can run `run_case.sh`, `regress.sh`, `open_gtkwave.sh`, etc. without `./scripts/…`.

When a case finishes, run **`t`** in the same shell to **`cd` into that case’s build directory** (ELF/HEX/log/VCD, etc.). The path is stored in `$RV32M_LAST_CASE_DIR_FILE` (default `$RV32M_ROOT/.open_rv32m_last_case_build_dir`).

Override site-specific variables **before** sourcing if your install paths differ, for example:

```bash
export VCS_HOME=/opt/synopsys/vcs/...
export TOOLCHAIN=/opt/riscv/bin
source scripts/open_rv.sh
```

If you keep a clone next to other projects and prefer to run **`source open_rv`** from the **parent** directory (e.g. `project/`), a thin **`open_rv`** there can forward to this script; the canonical file remains **`open_rv32m/scripts/open_rv.sh`**.

Equivalent from anywhere inside the tree:

```bash
source regress/env.sh
```

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
make regress TARGET=ahb                # AHB full list
make list
make env
```

Useful variables: `TARGET=core|ahb`, `CASE=<asm stem>`, `ASM=<path.S>`, `SIM=verilator|vcs`, `FSDB=1`, `VCD=1`, `TRACE=1`, `PC_TRACE=1`, `MAX_CYCLES=N`, `BUILD_DIR=...`, `REGRESS_CASE=<name>`.

`tests/core/asm/Makefile` is a tiny forwarder for **core** cases only; prefer `./scripts/run_case.sh` from the repo root.

## Regression

```bash
./scripts/regress.sh                    # core, full list
./scripts/regress.sh --target ahb       # AHB (skips core-only builtin)
./scripts/regress.sh --case alu
./scripts/regress.sh --waves            # VCD per case
./scripts/regress.sh --pc-trace
```

Case list: `regress/cases/core.list`.

Performance micro-benchmarks (also in the default list): `perf_alu_chain`, `perf_branch_loop`, `perf_loadstore_loop`, `perf_mul_loop`.

## Test termination (tohost)

Assembly tests signal PASS/FAIL by writing **`0xF000_0000`**:

- `1` → PASS (`$finish` success)
- any other value → FAIL

`max_cycles` is only a watchdog.

## Outputs

Single case under `build/sim/<target>/<case>/`: ELF, HEX, disassembly, log, optional VCD/FSDB, `pc_trace.tsv`, Verilator `obj_dir/` or VCS `simv`, helper `open_verdi.sh` when applicable.

Regression under `regress/results/<timestamp>/`: `summary.rpt`, per-case trees mirroring the layout above.

## Optional: Verdi

From a case directory that already ran with VCS/FSDB or VCD:

```bash
cd build/sim/core/smoke
./open_verdi.sh
```

Filelists: use `$RV32M_FILELIST_CORE` / `$RV32M_FILELIST_AHB` with tops `tb_rv32im_top` / `tb_rv32im_ahb_top`.

## Optional: Design Compiler

```bash
make -C dc
# or: ./scripts/dc_build.sh
```

See `dc/` for logs, reports, and mapped netlist paths (ignored from git by default).

## License

[LICENSE](LICENSE) is provided as **MIT** for open redistribution. If this core is derived from or must comply with another policy at your site, replace or supplement that file accordingly.
