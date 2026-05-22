# open_rv32m simulation

Simulation is driven from two entry points:

```text
Single case: ./scripts/run_case.sh
Regression:  ./scripts/regress.sh
```

`sim/Makefile` wraps those scripts for quick commands.

## Environment

From the repository root:

```bash
source scripts/open_rv.sh
# or: source regress/env.sh   # same effect
```

Important variables (see `scripts/open_rv.sh`):

- `RV32M_ROOT` — this repo
- `RV32M_RISCV_TOOLCHAIN_BIN`, `RV32M_RISCV_GNU_PREFIX` — RISC-V GNU toolchain
- `RV32M_VERILATOR`, `RV32M_VERILATOR_BIN_DIR`, `RV32M_GTKWAVE`
- `RV32M_VCS_HOME`, `RV32M_VERDI_HOME`, `RV32M_DC_HOME`, `RV32M_SNPSLMD_LICENSE_FILE` (optional)
- `RV32M_SIMULATOR` — `verilator` (default) or `vcs`
- `RV32M_FILELIST_CORE`, `RV32M_FILELIST_AHB`

**Verilator on older hosts (e.g. CentOS 7):** `verilator_build.sh` may source `devtoolset-11` (or 9/10). You can also `source /opt/rh/devtoolset-11/enable` before building, or set `RV32M_VERILATOR_BIN_DIR`.

## `sim/Makefile` (optional)

Forwards to `scripts/run_case.sh` / `scripts/regress.sh`. Prefer calling those scripts from the repo root.

```bash
cd sim
make run CASE=smoke
make ahb CASE=sbus
make run CASE=smoke SIM=vcs FSDB=1 PC_TRACE=1
make regress REGRESS_CASE=alu
make regress TARGET=ahb REGRESS_CASE=sbus PC_TRACE=1
make list
make env
```

Common variables:

```text
TARGET=core|ahb
CASE=<asm stem>
ASM=<explicit path to .S>
REGRESS_CASE=<one case name for make regress>
SIM=verilator|vcs
FSDB=1 VCD=1 TRACE=1 PC_TRACE=1 PC_TRACE_EACH_CYCLE=1 KDB=1
MAX_CYCLES=N BUILD_DIR=<dir> PC_TRACE_FILE=<file>
```

## Single case

```bash
./scripts/run_case.sh [options] tests/core/asm/smoke.S
```

Examples:

```bash
# Core, no waveform by default
./scripts/run_case.sh tests/core/asm/alu.S

# Core, FSDB (VCS + Verdi)
./scripts/run_case.sh --sim vcs --fsdb tests/core/asm/hazard.S

# AHB, FSDB (core asm or periph asm)
./scripts/run_case.sh --sim vcs --target ahb --fsdb tests/core/asm/sbus.S
./scripts/run_case.sh --target ahb tests/periph/apb_uart_sv/uart_smoke.S

# Custom output directory
./scripts/run_case.sh --sim vcs --target ahb --fsdb \
  --build-dir build/debug/sbus_ahb tests/core/asm/sbus.S
```

Default output:

```text
build/sim/core/<case>/
build/sim/ahb/<case>/
```

Typical contents:

```text
<case>.elf
<case>.hex
<case>.dump
<case>.sim.log           # TORV SoC
<case>.fsdb              # with --fsdb
<case>.vcd               # with --vcd
verilator/
  obj_dir/
    Vtb_torv_soc
  verilator.log
vcs/
  simv
  compile.log
  csrc/
  simv.daidir/
open_verdi.sh
run_case.log             # when invoked from regress
```

### `run_case.sh` options

- `--target soc` — TORV SoC (default). `core|ahb` are legacy aliases.
- `--sim verilator|vcs` — default `verilator`; FSDB/`--kdb` need VCS.
- `--fsdb` — FSDB (VCS only).
- `--vcd` — VCD.
- `--trace` — passes `+trace` to the testbench.
- `--pc-trace` — write `pc_trace.tsv` from the TB.
- `--pc-trace-file FILE` — PC trace path.
- `--pc-trace-each-cycle` — one line per cycle; default logs only when PC changes.
- `--kdb` — VCS KDB for Verdi source browsing (VCS only).
- `--max-cycles N` — watchdog limit.
- `--build-dir DIR` — output directory.

By default the case output directory is recreated. To keep it: `RV32M_KEEP_BUILD=1`.

## Regression

```bash
./scripts/regress.sh [options]
```

Examples:

```bash
./scripts/regress.sh
./scripts/regress.sh --case alu
./scripts/regress.sh --sim vcs --fsdb
./scripts/regress.sh --sim vcs --case sbus --fsdb
./scripts/regress.sh --case smoke --pc-trace
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
```

Case lists (default when `--case-list` omitted):

| `--target` | Default list |
|------------|----------------|
| `soc` | `regress/cases/soc.list` (29 asm cases) |
| `core` / `ahb` | legacy lists, still run through TORV SoC |

Other lists: `deep_hazard.list`, `periph_replay.list`, `periph.list`, `ahb_replay.list`.

First TORV SoC run fetches SoCBUS + PULP UART via `scripts/fetch_ip.sh` if missing (`ip/README.md`).

Regression tree:

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  soc/<case>/...
```

Notes:

- Each case has its own directory.
- `summary.rpt` aggregates status.
- Legacy `builtin` case type was removed; use `soc.list` asm tests only.
- Peripheral asm lives under `tests/periph/<ip>/`; `.plusargs` beside the `.S` file is auto-loaded.

## Performance counters

`tb_torv_soc` prints `[PERF]` before PASS when the asm case writes `tohost=1`:

```text
[PERF] cycles=<N> instr=<N> ipc=<N>
[PERF] type alu=<N> load=<N> store=<N> branch=<N> branch_taken=<N> jump=<N> muldiv=<N> lui_auipc=<N>
[PERF] stall if=<N> id=<N> ex=<N> flush=<N> dbus_r=<N> dbus_w=<N> sbus_r=<N> sbus_w=<N>
```

Semantics:

- `cycles` — cycles from reset deassert until PASS tohost.
- `instr` — non-NOP instructions entering EX (approximate retired count for this in-order core); excludes flush/stall bubbles and `addi x0,x0,0`.
- `ipc` — `instr / cycles`.
- `type` — coarse opcode mix.
- `stall` — observed stall/flush; under AHB includes bridge/memory effects.
- `dbus_*` / `sbus_*` — valid/ready (core) or non-IDLE transfers (AHB).

Built-in perf cases:

| Case | Role |
|------|------|
| `perf_alu_chain` | ALU chains, data hazards, branch cost |
| `perf_branch_loop` | Tight branch loop, taken-branch / flush |
| `perf_loadstore_loop` | DBUS load/store loop, memory stalls |
| `perf_mul_loop` | RV32M multiply loop |

Extract from a run:

```bash
rg "\[PERF\]" regress/results/<run>/<target>/*/*.sim.log
rg "\[PERF\]" regress/results/<run>/<target>/*/*.ahb.sim.log
```

## Test termination

Tests do not rely on simulation time for pass/fail. They write **`0xF000_0000`**:

```text
write 1     -> PASS, TB calls $finish(0)
write != 1  -> FAIL, TB calls $finish(1)
```

`MAX_CYCLES` / `--max-cycles` is a hang watchdog. New asm cases should use:

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS

fail:
  RVTEST_FAIL
```

## PC trace

The testbench writes TSV directly (no VCD/FSDB parsing required) for offline correlation with `objdump`:

```bash
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
./scripts/run_case.sh --target ahb --pc-trace tests/core/asm/sbus.S
./scripts/regress.sh --case smoke --pc-trace
```

### Bus stall plusargs (core TB only)

Directed deep-hazard cases ship a sibling `tests/core/asm/<case>.plusargs` file (loaded automatically by `run_case.sh`):

| Plusarg | Purpose |
|---------|---------|
| `+stall_sbus_writes=N` | Hold `sbus_ready` low for N cycles on the first SBUS store |
| `+stall_ibus_during_mem_write=N` | Hold `ibus_ready` low for N cycles while a store is in MEM |
| `+max_cycles=N` | Watchdog override (optional in `.plusargs`) |

### TORV peripheral plusargs (`tb_torv_soc`)

Used by `tests/periph/apb_uart_sv/*.plusargs` (replay / UART smoke):

| Plusarg | Purpose |
|---------|---------|
| `+replay_expect=N` | Expect exactly N THR pushes to PULP UART FIFO (checked on PASS/timeout) |
| `+stall_ibus_during_mem_write=N` | IBUS back-pressure during MEM store (replay stress) |

### Manual `simv` plusargs

| Plusarg | Meaning |
|---------|---------|
| `+pc_trace` | Enable PC trace file |
| `+pc_trace_file=<path>` | Output path (default `pc_trace.tsv`) |
| `+pc_trace_each_cycle` | Every cycle; **without** it, log only when **PC changes** |

Columns (tab-separated): `time_ps`, `pc_hex`, `ibus_inst_hex`, `if_id_pc_hex`, `if_id_inst_hex`, `wb_we`, `wb_rd`, `wb_wdata_hex` (WB fields are the MEM/WB stage in that cycle).

Use `scripts/check_hazard_dup_trace.py` on directed hazard cases to count `x1` writebacks without opening a waveform.

Example (from the case directory):

```bash
./vcs/simv +imem="$PWD/smoke.hex" +max_cycles=5000 \
  +pc_trace +pc_trace_file="$PWD/pc.tsv"
head pc.tsv
```

`ibus_inst_hex` and `if_id_inst_hex` are offset in the pipeline; align disassembly using `pc_hex` / `if_id_pc_hex`.

## Waveforms (VCD / GTKWave / FSDB)

VCD:

```bash
./scripts/run_case.sh --vcd tests/core/asm/smoke.S
./scripts/regress.sh --waves
```

**GTKWave** (install via your distro, or set `RV32M_GTKWAVE` in `scripts/open_rv.sh` / `open_rv.local.sh`):

```bash
./scripts/open_gtkwave.sh smoke
# Or: make run CASE=smoke VCD=1 && make gtkwave CASE=smoke
```

FSDB:

```bash
./scripts/run_case.sh --fsdb tests/core/asm/smoke.S
./scripts/regress.sh --fsdb
```

FSDB needs Verdi VCS PLI, typically:

```text
$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab
$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a
```

Scripts also try `LINUXAMD64`.

## Verdi

```bash
cd build/sim/core/alu
./open_verdi.sh
```

Regression helper:

```bash
regress/results/<run>/open_verdi.sh alu
```

`open_verdi.sh` picks filelist/top, prefers `<case>.fsdb`, else `<case>.vcd`, and adds `vcs/simv.daidir` when present.

Asm compile + simulator runs live under **`scripts/internal/`** (not a user entry point — use **`scripts/run_case.sh`**).

TORV peripheral RTL: `ip/third_party/socbus` (`AHB_APB_BRIDGE`), `ip/third_party/apb_uart_sv` — instantiated in `rtl/torv_soc_top.sv` (see `ip/README.md`, `scripts/fetch_ip.sh`).

## Troubleshooting

- **No FSDB** — use `--fsdb` with VCS; check `VERDI_HOME` / `NOVAS_HOME` and PLI paths.
- **Verdi no RTL** — re-run with `--kdb`.
- **License errors** — check `SNPSLMD_LICENSE_FILE` and related Synopsys variables.
