# Core Tests

This directory contains tests for `rv32im_core`.

Layout:

- `asm/`: bare-metal assembly tests compiled by the RISC-V toolchain.
- `link.ld`: minimal instruction-memory linker script.

## Test Termination

Assembly cases should terminate by writing a flag to `0xF0000000`:

- `1`: pass
- any other value: fail/error

The core and AHB testbenches stop immediately when they see this write. `max_cycles` remains only a watchdog for hung tests; it is not the normal pass/fail mechanism.

New cases can use `asm/test_macros.inc`:

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS

fail:
  RVTEST_FAIL
```

Current directed cases:

- `smoke.S`: minimal toolchain and tohost smoke.
- `alu.S`: ALU arithmetic, compare, logic, and shifts.
- `imm.S`: I-type immediates, sign extension, and LUI.
- `branch.S`: BEQ/BNE/BLT/BGE/BLTU/BGEU taken and not-taken paths.
- `compare_edges.S`: signed/unsigned compare edge cases around `0x80000000` and `0xffffffff`.
- `shift_edges.S`: edge shift amounts and register shift low-5-bit masking.
- `jump.S`: JAL/JALR control flow and link register nonzero checks.
- `flush.S`: branch/JAL/JALR flush behavior.
- `x0.S`: x0 hardwire behavior, including writes and loads to x0.
- `loadstore.S`: LB/LH/LW/LBU/LHU and SB/SH/SW on DBUS.
- `mem_offsets.S`: positive and negative load/store offsets.
- `sbus.S`: SBUS data access path plus byte write/read.
- `bus_mix_dbus_sbus.S`: interleaved DBUS/SBUS words (routing + cross-bus hazards).
- `bus_sbus_widths.S`: SBUS-only SW/LW, SH/LH/LHU, SB/LB/LBU.
- `bus_ibus_dbus_fill.S`: long IBUS run then several DBUS words (fetch/MEM overlap).
- `bypass.S`: ALU forwarding and load-use consumer paths.
- `muldiv.S`: RV32M multiply/divide corner cases.
- `muldiv_stall.S`: dependent consumers after multi-cycle DIV/REM.
- `hazard.S`: load-use, load-branch, and load-store hazard scenarios.
- `hazard_branch_mem_stall.S`: taken branch in EX while an SBUS store stalls MEM (needs `hazard_branch_mem_stall.plusargs`; targets flush vs `stall_mem` in `hazard_unit.sv`).
- `hazard_ibus_store_dup.S`: IBUS stall with store in MEM (needs `hazard_ibus_store_dup.plusargs`; targets `stall_id_ex` hack when `ex_mem_mem_write && ibus_stall`).

These two cases use testbench bus back-pressure (`+stall_sbus_writes` / `+stall_ibus_during_mem_write` in `sim/tb_rv32im_top.sv`). They are listed in `regress/cases/core.list` and also in `regress/cases/deep_hazard.list` for focused runs.

## Running tests

From the repository root (with `RV32M_ROOT` and the RISC-V toolchain configured):

```bash
./scripts/run_case.sh tests/core/asm/alu.S
./scripts/run_case.sh --target ahb tests/core/asm/sbus.S
```

With **VCD** for **GTKWave**:

```bash
./scripts/run_case.sh --vcd tests/core/asm/alu.S
./scripts/open_gtkwave.sh alu
```

From `sim/`:

```bash
cd sim
make run CASE=alu
make ahb CASE=sbus
make run CASE=smoke PC_TRACE=1
make run CASE=alu VCD=1
make gtkwave CASE=alu
```

Regression:

```bash
./scripts/regress.sh
./scripts/regress.sh --target ahb
```

Generated files are kept outside the source tree:

- single-case runs: `build/sim/core/<case>/`
- AHB single-case runs: `build/sim/ahb/<case>/`
- regress runs: `regress/results/<timestamp>/<target>/<case>/`
