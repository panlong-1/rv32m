# TORV regression

## Entry point

```bash
./scripts/regress.sh [options]
```

`scripts/regress.sh` is a thin wrapper around `regress/bin/run_regress.py`. Every case runs
through `scripts/run_case.sh` on the TORV SoC testbench (`sim/tb_torv_soc.sv` +
`rtl/torv_soc.sv`) with Verilator.

## Commands

```bash
./scripts/regress.sh                              # regress/cases/soc.list (33 cases)
./scripts/regress.sh --case alu --case muldiv     # selected cases
./scripts/regress.sh --case-list regress/cases/deep_hazard.list
./scripts/regress.sh --waves                      # one VCD per case
./scripts/regress.sh --pc-trace                   # pc_trace.tsv per case
./scripts/regress.sh --pc-trace-each-cycle
./scripts/regress.sh --trace
./scripts/regress.sh --keep                       # keep existing per-case directories
```

`sim/Makefile` has shortcuts for the same commands:

```bash
make -C sim regress
make -C sim regress REGRESS_CASE=alu PC_TRACE=1
```

The third-party IP (SoCBUS + PULP UART) is fetched automatically on the first run by
`scripts/fetch_ip.sh`.

## Case lists

| File | Cases | Contents |
|------|-------|----------|
| **`regress/cases/soc.list`** | 33 | **Canonical full regression**: ISA, hazards, buses, SRAM write buffer, perf, UART/replay |
| `regress/cases/deep_hazard.list` | 6 | Directed hazard subset (`hazard_branch_mem_stall`, `hazard_ibus_{store,insn,load}_dup`, `hazard_sbus_{,rx_}replay_smoke`) |
| `regress/cases/periph_replay.list` | 3 | `uart_smoke`, `replay_ibus_store`, `replay_div_store` |
| `regress/cases/periph.list` | 1 | UART smoke |
| `regress/cases/ahb_replay.list` | 3 | Replay subset |
| `regress/cases/core.list` / `ahb.list` | 28 / 5 | Legacy lists (`--target core` / `--target ahb`), all subsets of `soc.list` |

`--target core|ahb` only selects the legacy list. The simulation is always the TORV SoC.

Line format:

```text
name type source max_cycles
```

`type` is `asm`: the given `.S` is assembled (from `tests/core/asm/` or `tests/periph/<ip>/`)
and loaded with `+imem=<hex>`. A `<case>.plusargs` next to the source is applied automatically.
`max_cycles` is a watchdog only. Pass or fail comes from the store to **`0xF000_0000`**:
`1` = pass, anything else = fail.

## Outputs

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt              # case,status,detail (CSV)
  perf_summary.csv         # only when every case passed
  perf_summary.log
  soc/<case>/
    <case>.elf  <case>.hex  <case>.dump
    <case>.sim.log
    <case>.vcd             # --waves
    pc_trace.tsv           # --pc-trace
    run_case.log
    verilator/
```

`perf_summary.csv` has one row per case. Columns: cycles, instructions, IPC, instruction mix,
IF/ID/EX stall cycles, flushes, DBUS/SBUS read and write cycles.

```bash
./scripts/perf_summary.py                              # latest results dir
./scripts/perf_summary.py regress/results/<stamp> --csv out.csv
```

## Directed checks without waveforms

`hazard_ibus_insn_dup` and `hazard_ibus_load_dup` check that an IBUS stall during MEM does not
duplicate a writeback:

```bash
./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup --run
./scripts/check_hazard_dup_trace.py --case hazard_ibus_load_dup --run
```
