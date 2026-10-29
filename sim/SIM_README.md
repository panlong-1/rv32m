# rv32m simulation

All simulation is **Verilator** on the TORV SoC testbench `sim/tb_torv_soc.sv`. There are two
entry points:

```text
Single case: ./scripts/run_case.sh
Regression:  ./scripts/regress.sh
```

`sim/Makefile` wraps both for quick commands. The assembler, the Verilator build and the run
itself live in `scripts/internal/run_soc_sim.sh` and `scripts/verilator_build.sh`; those are not
user entry points.

## Environment

From the repository root:

```bash
source scripts/env.sh
# or: source regress/env.sh   # same effect
```

Variables (see `scripts/env.sh`):

- `TORV_ROOT` — this repository.
- `TORV_RISCV_TOOLCHAIN_BIN`, `TORV_RISCV_GNU_PREFIX` — RISC-V GNU toolchain. It defaults
  to `$PROJECT_ROOT/riscv_toolchain/bin`, falling back to `/usr/bin` for the Ubuntu package.
- `TORV_VERILATOR`, `TORV_VERILATOR_BIN_DIR`, `TORV_GTKWAVE`.
- `PDK_ROOT` — IHP SG13G2 PDK (default `~/.ciel`). The SoC SRAMs are simulated with the PDK
  models `$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_*.v`, which
  `rtl/filelist.f` lists, compiled with `-DFUNCTIONAL`.

Verilator flags (`scripts/verilator_build.sh`):

- `--binary --timing --trace -O1 -DFUNCTIONAL`.
- `-Wno-fatal -Wno-TIMESCALEMOD -Wno-ASSIGNIN`. `ASSIGNIN` is needed because the testbench
  `force`s UART FIFO inputs.
- **Older hosts (e.g. CentOS 7):** the script sources `devtoolset-11/10/9` when the default
  `g++` cannot build C++17. You can also set `CXX`.

## `sim/Makefile` (optional)

These targets forward to `scripts/run_case.sh` and `scripts/regress.sh`:

```bash
make -C sim run CASE=smoke
make -C sim run CASE=hazard VCD=1 PC_TRACE=1
make -C sim gtkwave CASE=hazard
make -C sim regress
make -C sim regress REGRESS_CASE=alu
make -C sim list
make -C sim env
```

Variables:

```text
CASE=<asm stem>            ASM=<explicit path to .S>
REGRESS_CASE=<case name>   (one case for make regress)
VCD=1 TRACE=1 PC_TRACE=1 PC_TRACE_EACH_CYCLE=1
MAX_CYCLES=N BUILD_DIR=<dir> PC_TRACE_FILE=<file>
```

## Single case

```bash
./scripts/run_case.sh [options] tests/core/asm/smoke.S
```

Examples:

```bash
./scripts/run_case.sh tests/core/asm/alu.S
./scripts/run_case.sh --vcd tests/core/asm/hazard.S
./scripts/run_case.sh tests/periph/apb_uart_sv/uart_smoke.S
./scripts/run_case.sh --vcd --build-dir build/debug/sbus tests/core/asm/sbus.S
```

### `run_case.sh` options

- `--vcd` (`--waves`) — dump `<case>.vcd`.
- `--trace` — pass `+trace` to the testbench.
- `--pc-trace` — write `pc_trace.tsv`.
- `--pc-trace-file FILE` — PC trace path.
- `--pc-trace-each-cycle` — one row per cycle. By default a row is written only when the PC
  changes.
- `--max-cycles N` — watchdog limit (default 20000).
- `--build-dir DIR` — output directory (default `build/sim/soc/<case>/`).
- `--target soc` — the only target. `core` and `ahb` are accepted as deprecated aliases.
- `--sim verilator` — accepted for compatibility; Verilator is the only simulator.

The case directory is recreated on every run. To keep it, set `TORV_KEEP_BUILD=1`.

Output:

```text
build/sim/soc/<case>/
  <case>.elf  <case>.hex  <case>.dump
  <case>.sim.log           # testbench log ([PERF], [PASS]/[FAIL])
  <case>.vcd               # with --vcd
  pc_trace.tsv             # with --pc-trace
  verilator/obj_dir/Vtb_torv_soc
  verilator/verilator.log
  run_case.log             # when invoked from regress
```

## Program loading (ELF / HEX)

The CPU does **not** load the ELF at runtime. `run_case.sh` builds a memory image, and the
testbench loads it into the SRAM macro arrays **before reset**:

| Step | What happens |
|------|--------------|
| 1 | `${PREFIX}gcc -march=rv32im -mabi=ilp32 -nostdlib` with `tests/core/link.ld` produces `<case>.elf` (`.text` at `0x0000_0000`) |
| 2 | `objcopy -O verilog` produces `<case>.hex` |
| 3 | `+imem=<case>.hex` loads the image into the instruction SRAM (`u_i_sram`). The rest of IMEM is filled with NOPs. An image larger than the macro is an error. |
| 4 | Optional `+dmem=<file>.hex` loads the data SRAM. Most tests write their data with stores to `0x2000_0000`. |
| 5 | Reset is released and the core fetches from PC `0x0`. |

The SRAMs are IHP `RM_IHPSG13_1P_<WORDS>x32` macros. The testbench writes their behavioral
`memory` arrays directly through hierarchical paths (`TORV_IMEM` / `TORV_DMEM` / `TORV_SMEM`
macros in `tb_torv_soc.sv`). The default size is 1024 words (4 KiB) each. See
[docs/torv_address_map.md](../docs/torv_address_map.md) and [docs/loading.md](../docs/loading.md).

## Regression

```bash
./scripts/regress.sh [options]
```

```bash
./scripts/regress.sh                              # regress/cases/soc.list (33 cases)
./scripts/regress.sh --case alu
./scripts/regress.sh --case smoke --pc-trace
./scripts/regress.sh --case-list regress/cases/deep_hazard.list
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
```

Options:
- `--case NAME` (repeatable);
- `--case-list FILE`;
- `--waves`;
- `--trace`;
- `--pc-trace`, `--pc-trace-each-cycle`;
- `--keep` — keep per-case directories.

The first run fetches SoCBUS and the PULP UART with `scripts/fetch_ip.sh` if they are missing
(see `ip/README.md`).

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt              # case,status,detail
  perf_summary.csv         # written when all cases pass
  soc/<case>/...
```

Peripheral tests live under `tests/periph/<ip>/`. A `.plusargs` file next to the `.S` is loaded
automatically.

## Performance counters

`tb_torv_soc` prints `[PERF]` lines before PASS:

```text
[PERF] cycles=<N> instr=<N> ipc=<N>
[PERF] type alu=<N> load=<N> store=<N> branch=<N> branch_taken=<N> jump=<N> muldiv=<N> lui_auipc=<N>
[PERF] stall if=<N> id=<N> ex=<N> flush=<N> dbus_r=<N> dbus_w=<N> sbus_r=<N> sbus_w=<N>
```

- `cycles` — cycles from reset deassertion until the PASS `tohost` store.
- `instr` — non-NOP instructions entering EX. This is approximately the retired count for this
  in-order core; bubbles and `addi x0,x0,0` are excluded.
- `ipc` — `instr / cycles`.
- `stall` / `flush` — cycles with the corresponding pipeline hold or flush.
- `dbus_*` / `sbus_*` — cycles with a non-IDLE AHB address phase (read/write).

`scripts/perf_summary.py <result-dir> --csv out.csv` collects them into one table.

| Case | Role |
|------|------|
| `perf_alu_chain` | ALU chains, forwarding, loop branch |
| `perf_branch_loop` | Tight branch loop: taken branches and flushes |
| `perf_loadstore_loop` | DBUS load/store loop |
| `perf_mul_loop` | RV32M multiply loop (two-cycle `MUL`) |

## Test termination

Tests store to **`0xF000_0000`** (`tohost`). The testbench samples that store when SBUS HREADY
is high:

```text
write 1     -> [PASS] TORV, $finish(0)
write != 1  -> [FAIL], $finish(1)
```

`--max-cycles` is only a hang watchdog. New assembly cases use the macros:

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS
fail:
  RVTEST_FAIL
```

## Testbench plusargs

| Plusarg | Purpose |
|---------|---------|
| `+imem=<hex>` / `+dmem=<hex>` | Program / data image |
| `+max_cycles=N` | Watchdog (also allowed inside `.plusargs`) |
| `+vcd`, `+vcdfile=<path>` | VCD dump |
| `+trace` | Testbench trace prints |
| `+pc_trace`, `+pc_trace_file=<path>`, `+pc_trace_each_cycle` | PC / WB trace TSV |
| `+stall_sbus_writes=N` | Hold SBUS HREADY low for N cycles on the first SBUS store |
| `+stall_ibus_during_mem_write=N` | Hold IBUS HREADY low for N cycles while a store is in MEM |
| `+replay_expect=N` | Fail if more than N UART THR pushes are seen (bus replay check) |
| `+replay_expect_rbr=N` | Expect exactly N UART RBR reads |
| `+uart_rx_byte=<hex>` | Byte injected into the UART RX FIFO |

## PC trace

```bash
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup --run
```

The trace is tab-separated, with columns `time_ps`, `pc_hex`, `ibus_inst_hex`, `if_id_pc_hex`,
`if_id_inst_hex`, `wb_we`, `wb_rd`, `wb_wdata_hex`. The WB fields are the MEM/WB stage in that
cycle. `ibus_inst_hex` and `if_id_inst_hex` sit at different pipeline stages, so align them with
the disassembly using `pc_hex` / `if_id_pc_hex`. `check_hazard_dup_trace.py` counts `x1`
writebacks in the directed hazard cases without opening a waveform.

To rerun a built simulator by hand from the case directory:

```bash
./verilator/obj_dir/Vtb_torv_soc +imem="$PWD/smoke.hex" +max_cycles=5000 \
  +pc_trace +pc_trace_file="$PWD/pc.tsv"
```

## Waveforms (VCD / GTKWave)

```bash
./scripts/run_case.sh --vcd tests/core/asm/smoke.S
./scripts/open_gtkwave.sh smoke                   # build/sim/soc/smoke/smoke.vcd
./scripts/open_gtkwave.sh --vcd path/to/file.vcd
./scripts/regress.sh --waves                      # one VCD per case
```

To use a GTKWave binary that is not on `PATH`, set `TORV_GTKWAVE`.

## Troubleshooting

- **`IHP SRAM models: MISSING`** when sourcing `env.sh` — install the `ihp-sg13g2` PDK
  (see [docs/open_source_flow.md](../docs/open_source_flow.md)) or point `PDK_ROOT` at it.
- **`riscv64-unknown-elf-gcc: not found`** — install `gcc-riscv64-unknown-elf` or set
  `TORV_RISCV_TOOLCHAIN_BIN` / `TORV_RISCV_GNU_PREFIX`.
- **Verilator C++ build fails** — check `build/sim/soc/<case>/verilator/verilator.log`. You need
  Verilator ≥ 5.0 (for `--timing`) and a C++17 compiler.
- **`TIMEOUT waiting for TORV tohost`** — the program never reached `tohost`. Rerun with
  `--pc-trace` or `--vcd`.
