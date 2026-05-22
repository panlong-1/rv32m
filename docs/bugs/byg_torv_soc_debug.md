# BYG: TORV SoC Integration Debug Record

Date: 2026-05-23  
Scope: `torv_soc_top`, `tb_torv_soc`, CPU memory replay / hazard control, TORV address map.

## Summary

TORV SoC integration initially reproduced several failures after moving from legacy `core` / `ahb` testbenches into the single `torv_soc_top` + `tb_torv_soc` path.

Final verification:

```bash
./scripts/regress.sh
```

Result:

```text
regress/results/20260523_031941/summary.rpt
PASS 29
```

## Bugs Fixed

### BYG-001: TORV SBUS address collision

Symptom:

- `sbus`, `bus_mix_dbus_sbus`, `bus_sbus_widths`, and related core SBUS tests timed out or failed after moving UART into the SoC.

Cause:

- Legacy core tests use `0x4000_0000` as generic SBUS data memory.
- PULP UART was initially mapped at `0x4000_0000`, so normal SBUS SRAM tests were routed into APB UART.
- `torv_ahb_sram` also indexed memory with full 32-bit addresses, unlike the legacy Harvard TB which used low address bits.

Fix:

- Keep SBUS SRAM behavior compatible with core tests by indexing `torv_ahb_sram` with low 16 address bits.
- Move TORV APB UART to `0x4000_1000` to avoid collision with `0x4000_0000` SBUS data tests.
- Update peripheral asm tests and replay smoke to use `0x4000_1000`.

Evidence:

- `sbus`: PASS
- `bus_sbus_widths`: PASS
- `bus_mix_dbus_sbus`: PASS
- `uart_smoke`: PASS

### BYG-002: Completed load lost during IBUS front-end stall

Symptom:

- `hazard`, `hazard_branch_mem_stall`, and `bus_mix_dbus_sbus` failed or hung.
- Runtime trace showed completed loads stuck in `EX/MEM` during an IBUS stall; load-use consumers never observed the returned value.

Cause:

- `hazard_unit` treated a completed load like a store/ALU op during `ibus_stall`, holding or bubbling `EX/MEM` in a way that prevented the returned data from reaching `MEM/WB`.

Fix:

- In `hazard_unit`, when DBUS/SBUS beat is done and `ex_mem_mem_read` is active, allow the completed load to advance into `MEM/WB` even while IF/ID remains stalled.

Evidence:

- `hazard`: PASS
- `hazard_branch_mem_stall`: PASS
- `bus_mix_dbus_sbus`: PASS

### BYG-003: Completed store held forever during IBUS stall

Symptom:

- `hazard_ibus_store_dup` timed out.
- Trace showed a completed SBUS store staying in `EX/MEM` indefinitely while `IBUS` was stalled.

Cause:

- After a store beat completed and `rv32im_core` masked `sbus_valid`, `hazard_unit` still held `EX/MEM` because `ibus_stall` remained true.

Fix:

- For a completed store during `ibus_stall`, bubble `EX/MEM` while keeping `ID/EX` frozen. This clears the completed store and lets the frozen instruction advance exactly once later.

Evidence:

- `hazard_ibus_store_dup`: PASS

### BYG-004: UART THR store replay

Symptom:

- `uart_smoke` and `replay_div_store` failed with `periph TX count 4 != expected 1`.
- Trace showed the same APB UART THR store issuing multiple AHB address phases.

Cause:

- The replay guard expression briefly allowed `sbus_valid` to reassert after the bridge became ready-low/ready-high across repeated cycles.

Fix:

- `rv32im_core` now drops `dbus_valid` / `sbus_valid` after a completed store while `EX/MEM` is held.
- The guard applies to stores only, so loads can keep progressing and retire normally.

Evidence:

- `uart_smoke`: PASS
- `replay_ibus_store`: PASS
- `replay_div_store`: PASS
- `hazard_sbus_replay_smoke`: PASS

## Regression Evidence

Final run (this workspace):

```text
regress/results/20260523_031941/summary.rpt
PASS 29
```

Earlier failing run (before fixes, for comparison):

```text
regress/results/20260523_023105/summary.rpt
```

Notable deltas after fixes:

- `hazard`, `hazard_branch_mem_stall`, `hazard_ibus_store_dup`, `bus_mix_dbus_sbus` — PASS
- `hazard_sbus_replay_smoke` — PASS (uses `+replay_expect=1`, UART @ `0x4000_1000`)
- `uart_smoke`, `replay_*` — PASS

If you still see failures locally, ensure you have the latest tree (especially `hazard_sbus_replay_smoke.S`, `rtl/hazard_unit.sv`, `rtl/rv32im_core.sv`) and run:

```bash
./scripts/regress.sh
```

```text
hazard_ibus_store_dup PASS
uart_smoke PASS
replay_div_store PASS
hazard PASS
hazard_branch_mem_stall PASS
bus_mix_dbus_sbus PASS
hazard_sbus_replay_smoke PASS
```

## Code Locations

- `rtl/torv_soc_top.sv`: TORV address map and UART APB window.
- `rtl/torv_ahb_sram.sv`: low-16-bit SRAM indexing compatibility with legacy tests.
- `rtl/hazard_unit.sv`: completed load/store behavior under `ibus_stall`.
- `rtl/rv32im_core.sv`: store-only replay guard for DBUS/SBUS valid.
- `sim/tb_torv_soc.sv`: TORV single testbench, replay expectation, directed bus stalls.
- `tests/periph/apb_uart_sv/*.S`: UART base at `0x4000_1000`.
- `tests/core/asm/hazard_sbus_replay_smoke.S`: TORV UART replay smoke.
