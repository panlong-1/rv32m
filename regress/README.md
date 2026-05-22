# open_rv32m regression

## Entry point

```bash
./scripts/regress.sh [options]
```

`scripts/regress.sh` is a thin wrapper around `regress/bin/run_regress.py`.

## Targets

- `--target soc` (default) — `sim/tb_torv_soc.sv` + `rtl/torv_soc_top.sv`.
- `--target core` / `--target ahb` — legacy aliases; run the TORV SoC simulator while selecting older case lists if requested.

Default case lists (no `--case-list` needed):

| `--target` | List file |
|------------|-----------|
| `soc` (default) | `regress/cases/soc.list` |
| `core` (legacy list) | `regress/cases/core.list` |
| `ahb` (legacy list) | `regress/cases/ahb.list` |

TORV full regression is **`regress/cases/soc.list`** (32 asm cases). Legacy `builtin` in old lists is skipped/removed.

On successful full regress, `regress/results/<stamp>/perf_summary.csv` is generated automatically.

```bash
./scripts/perf_summary.py                              # latest results dir
./scripts/perf_summary.py regress/results/<stamp> --csv out.csv
```

Optional subsets:

```bash
./scripts/regress.sh --case-list regress/cases/deep_hazard.list   # 6 hazard cases
./scripts/regress.sh --target ahb --case-list regress/cases/periph_replay.list
```

Directed dup checks (PC trace + x1 writeback count):

```bash
./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup --run
```

Third-party IP (SoCBUS + PULP UART) is fetched automatically on first AHB run via `scripts/fetch_ip.sh`.

## Commands

```bash
./scripts/regress.sh
./scripts/regress.sh --case alu
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

## Case lists

| File | Target | Contents |
|------|--------|----------|
| `regress/cases/core.list` | core | 24 asm + 4 perf (legacy list alias) |
| `regress/cases/ahb.list` | ahb | smoke, sbus + `tests/periph/apb_uart_sv/*` |
| `regress/cases/deep_hazard.list` | core | `hazard_branch_mem_stall`, `hazard_ibus_store_dup`, `hazard_sbus_replay_smoke` |
| `regress/cases/periph_replay.list` | ahb | `uart_smoke`, `replay_ibus_store`, `replay_div_store` |
| `regress/cases/periph.list` | ahb | all `apb_uart_sv` asm |
| `regress/cases/ahb_replay.list` | ahb | replay subset |

Line format:

```text
name type source max_cycles
```

Types:

- `asm` — compile the given `.S` (core: `tests/core/asm/`; periph: `tests/periph/<ip>/`) and load with `+imem=<hex>`.

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
