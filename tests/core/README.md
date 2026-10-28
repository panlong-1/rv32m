# Core tests

Bare-metal RISC-V assembly tests. They run on the TORV SoC testbench (`sim/tb_torv_soc.sv`) with
Verilator.

Layout:

- `asm/` — test sources (`*.S`), shared macros `test_macros.inc`, per-case `*.plusargs`.
- `link.ld` — minimal linker script: `.text` at `0x0000_0000` (instruction SRAM).

## Test termination

A case ends by storing a flag to `0xF000_0000` (`tohost`):

- `1`: pass
- any other value: fail

The testbench stops as soon as it sees this store. `max_cycles` is only a watchdog for hung
tests. New cases should use `asm/test_macros.inc`:

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS

fail:
  RVTEST_FAIL
```

Data addresses by convention: DBUS SRAM at `0x2000_0000`, SBUS SRAM at `0x4000_0000` (4 KiB
each by default). See [docs/torv_address_map.md](../../docs/torv_address_map.md).

## Cases (all in `regress/cases/soc.list`)

ISA and pipeline:

- `smoke.S` — minimal toolchain and `tohost` smoke.
- `alu.S` — ALU arithmetic, compare, logic and shifts.
- `imm.S` — I-type immediates, sign extension and LUI.
- `branch.S` — BEQ/BNE/BLT/BGE/BLTU/BGEU, taken and not-taken.
- `compare_edges.S` — signed/unsigned compares around `0x80000000` and `0xffffffff`.
- `shift_edges.S` — edge shift amounts and low-5-bit masking of register shift amounts.
- `jump.S` — JAL/JALR control flow and link registers.
- `flush.S` — branch/JAL/JALR flush behavior.
- `x0.S` — x0 is hardwired, including writes and loads to x0.
- `bypass.S` — ALU forwarding and load-use consumers.
- `muldiv.S` — RV32M multiply/divide/remainder, including divide-by-zero and overflow.
- `muldiv_stall.S` — dependent consumers after multi-cycle MUL/DIV/REM.
- `hazard.S` — load-use, load-branch and load-to-store-data hazards.

Memory and buses:

- `loadstore.S` — LB/LH/LW/LBU/LHU and SB/SH/SW on DBUS.
- `mem_offsets.S` — positive and negative load/store offsets.
- `sbus.S` — SBUS data path, including byte write/read.
- `bus_mix_dbus_sbus.S` — interleaved DBUS/SBUS words (routing and cross-bus hazards).
- `bus_sbus_widths.S` — SBUS-only SW/LW, SH/LH/LHU, SB/LB/LBU.
- `bus_ibus_dbus_fill.S` — long IBUS run followed by several DBUS words (fetch/MEM overlap).
- `sram_wbuf.S` — back-to-back store/load patterns that exercise the `torv_ahb_sram` write
  buffer and the byte/halfword/word read merge on DBUS and SBUS.

Directed bus-stall hazards (these use testbench back-pressure from `<case>.plusargs`):

- `hazard_branch_mem_stall.S` — taken branch in EX while an SBUS store stalls MEM
  (`+stall_sbus_writes`).
- `hazard_ibus_store_dup.S`, `hazard_ibus_insn_dup.S`, `hazard_ibus_load_dup.S` — IBUS stall
  while a store/ALU op/load is in MEM (`+stall_ibus_during_mem_write`). They check that no
  instruction or writeback is duplicated. For the PC/WB trace check, run
  `scripts/check_hazard_dup_trace.py --case <case> --run`.
- `hazard_sbus_replay_smoke.S` / `hazard_sbus_rx_replay_smoke.S` — IBUS stall during a UART
  THR store / RBR read at `0x4000_1000`. Checks that no AHB/APB access is replayed
  (`+replay_expect=1`, `+replay_expect_rbr=1`).

Performance (cycle counts and IPC in `[PERF]`):

- `perf_alu_chain.S`, `perf_branch_loop.S`, `perf_loadstore_loop.S`, `perf_mul_loop.S`.

The PULP UART peripheral and replay cases live under `tests/periph/apb_uart_sv/`. See
[tests/periph/README.md](../periph/README.md).

## Running tests

From the repository root, after `source scripts/open_rv.sh`:

```bash
./scripts/run_case.sh tests/core/asm/alu.S
./scripts/run_case.sh --vcd tests/core/asm/alu.S && ./scripts/open_gtkwave.sh alu
./scripts/run_case.sh --pc-trace tests/core/asm/hazard_ibus_insn_dup.S
./scripts/regress.sh                    # all 33 cases
./scripts/regress.sh --case alu
```

From `sim/`: `make run CASE=alu VCD=1`, `make gtkwave CASE=alu`, `make regress`.

Generated files stay outside the source tree:

- single-case runs: `build/sim/soc/<case>/`
- regression runs: `regress/results/<timestamp>/soc/<case>/`
