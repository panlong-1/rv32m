# open_rv32m regression

## Entry point

```bash
./scripts/regress.sh [options]
```

`scripts/regress.sh` is a thin wrapper around `regress/bin/run_regress.py`.

## Targets

- `--target core` (default) — `sim/tb_rv32im_top.sv`.
- `--target ahb` — `sim/tb_rv32im_ahb_top.sv` + `sim/ahb_sram_model.sv`.
- `--target soc` — reserved.

AHB mode skips `builtin`; other asm cases share `regress/cases/core.list` with core.

Bus-overlap hazard subset (same asm sources, optional plusargs loaded by `run_case.sh`):

```bash
./scripts/regress.sh --case-list regress/cases/deep_hazard.list
```

## Commands

```bash
./scripts/regress.sh
./scripts/regress.sh --target ahb
./scripts/regress.sh --case alu
./scripts/regress.sh --target ahb --case sbus
./scripts/regress.sh --fsdb
./scripts/regress.sh --waves
./scripts/regress.sh --pc-trace
./scripts/regress.sh --pc-trace-each-cycle
./scripts/regress.sh --trace
```

`sim/Makefile` (optional shortcuts to the same scripts):

```bash
cd sim
make regress
make regress REGRESS_CASE=alu
make regress TARGET=ahb REGRESS_CASE=sbus
make regress PC_TRACE=1 FSDB=1
```

## Case list

Default file:

```text
regress/cases/core.list
```

Line format:

```text
name type source max_cycles
```

Types:

- `builtin` — self-check inside the core testbench.
- `asm` — compile `tests/core/asm/*.S` and load with `+imem=<hex>`.

`max_cycles` is a watchdog only. Pass/fail uses write to **`0xF000_0000`**: `1` = pass, non-1 = fail.

## Outputs

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  core/<case>/...
  ahb/<case>/...
```

Per case:

```text
<case>/
  <case>.elf
  <case>.hex
  <case>.dump
  <case>.sim.log           # core
  <case>.ahb.sim.log       # AHB
  <case>.fsdb              # --fsdb
  <case>.vcd               # --waves
  pc_trace.tsv             # --pc-trace
  run_case.log
  vcs/...
  open_verdi.sh
```

`summary.rpt` is CSV:

```text
case,status,detail
smoke,PASS,<path under regress/results/.../core/smoke>
```

## Verdi

```bash
regress/results/<run>/open_verdi.sh <case>
```

or:

```bash
cd regress/results/<run>/core/smoke
./open_verdi.sh
```
