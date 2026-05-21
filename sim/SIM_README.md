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

Important variables:

- `RV32M_ROOT` — this repo
- `TOOLCHAIN` — RISC-V GNU toolchain `bin` directory (if used by your flow)
- `RV32M_SIMULATOR` — `verilator` (default) or `vcs`
- Commercial flow: `VCS_HOME`, `VERDI_HOME` / `NOVAS_HOME`, `SNPSLMD_LICENSE_FILE`
- `RV32M_FILELIST_CORE`, `RV32M_FILELIST_AHB`

**Verilator on older hosts (e.g. CentOS 7):** `verilator_build.sh` may source `devtoolset-11` (or 9/10). You can also `source /opt/rh/devtoolset-11/enable` before building. See `scripts/install_verilator_centos7.sh`.

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

# AHB, FSDB
./scripts/run_case.sh --sim vcs --target ahb --fsdb tests/core/asm/sbus.S

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
<case>.sim.log           # core
<case>.ahb.sim.log       # AHB
<case>.fsdb              # with --fsdb
<case>.vcd               # with --vcd
verilator/
  obj_dir/
    Vtb_rv32im_top       # or Vtb_rv32im_ahb_top executable
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

- `--target core|ahb` — core TB vs AHB top TB.
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
./scripts/regress.sh --sim vcs --target ahb --case sbus --fsdb
./scripts/regress.sh --case smoke --pc-trace
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
./scripts/regress.sh --target ahb --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
```

Case list: `regress/cases/core.list`.

Regression tree:

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  core/<case>/...
  ahb/<case>/...
```

Notes:

- Each case has its own directory.
- `summary.rpt` aggregates status.
- AHB mode skips `builtin` (core-only).

## Performance counters

`tb_rv32im_top` and `tb_rv32im_ahb_top` print `[PERF]` before PASS when the asm case writes `tohost=1`:

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

Manual `simv` plusargs:

| Plusarg | Meaning |
|---------|---------|
| `+pc_trace` | Enable PC trace file |
| `+pc_trace_file=<path>` | Output path (default `pc_trace.tsv`) |
| `+pc_trace_each_cycle` | Every cycle; **without** it, log only when **PC changes** |

Columns (tab-separated): `time_ps`, `pc_hex`, `ibus_inst_hex`, `if_id_pc_hex`, `if_id_inst_hex`.

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

**GTKWave** (install via distro packages or `scripts/install_gtkwave_centos7.sh`):

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

## Implementation layout

Asm compile + simulator runs are implemented under **`scripts/internal/`**. That directory is **not** a supported user entry point — always go through **`scripts/run_case.sh`**.

## Troubleshooting

- **No FSDB** — use `--fsdb` with VCS; check `VERDI_HOME` / `NOVAS_HOME` and PLI paths.
- **Verdi no RTL** — re-run with `--kdb`.
- **License errors** — check `SNPSLMD_LICENSE_FILE` and related Synopsys variables.
