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

Initial fix (superseded by BYG-006):

- Allowed completed loads to advance `EX/MEM` while `stall_id_ex` stayed high — fixed load-use data visibility but duplicated non-memory ops in `EX/MEM`.

Final approach:

- See BYG-006: global `stall_front` freeze; bridge `rdata_q` + `dbus_completed` hold load data.

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

- `rv32im_core` drops `dbus_valid` / `sbus_valid` after any completed beat while `EX/MEM` is held (`dbus_completed` / `sbus_completed` without `ex_mem_mem_write` filter). See BYG-005.

Evidence:

- `uart_smoke`: PASS
- `replay_ibus_store`: PASS
- `replay_div_store`: PASS
- `hazard_sbus_replay_smoke`: PASS

### BYG-005: MMIO read replay (UART RBR over-pops RX FIFO)

Symptom:

- Directed `hazard_sbus_rx_replay_smoke` (with `+replay_expect_rbr=1`) fails when `dbus_completed` / `sbus_completed` only tracked **writes**.
- During `ibus_stall`, a completed `lw` from UART RBR (`0x4000_1000`) re-issued on SBUS; each replay pops the RX FIFO again.

Cause:

- Store-only replay guard treated loads as idempotent. SRAM reads are; UART RBR reads are not.

Fix:

- Extend `sbus_completed` to **loads and stores** on SBUS (`ex_mem_mem_read || ex_mem_mem_write`). DBUS replay guard stays **store-only** (SRAM reads are idempotent).

Evidence:

- `hazard_sbus_rx_replay_smoke`: PASS (`uart_rbr_read_count == 1`, `+replay_expect_rbr=1`)

### BYG-006: Instruction duplication during `stall_front` (fixed)

Symptom:

- With `stall_id_ex = 1` and an empty `else if (ex_mem_mem_read)` branch, `stall_ex_mem` stayed at the combinational default `0`. `EX/MEM` re-captured the frozen `ID/EX` instruction (duplicate `addi`).

Cause:

- SystemVerilog `always_comb` defaults assign `stall_ex_mem = 0`; a comment-only branch does not hold the stage.

Fix:

- `stall_front` defaults to freezing PC/IF/ID/EX/MEM when the IBUS or divider is busy.
- **Completed load** (`ex_mem_mem_read && dbus_done/sbus_done`): `stall_ex_mem = 0` so `MEM/WB` can retire while `ID/EX` stays frozen.
- **Completed store** during `ibus_stall`: `bubble_ex_mem` with `stall_ex_mem = 0` so the bubble clears `EX/MEM` (BYG-003).
- Pending beat (`!dbus_done && !sbus_done`): `stall_ex_mem = (dbus_valid || sbus_valid || stall_id_ex)`.
- `rv32im_core`: clear `dbus_completed` / `sbus_completed` only after `EX/MEM` has no matching mem op.

Evidence:

- `hazard_ibus_insn_dup`: PASS
- `hazard_ibus_store_dup`: PASS
- `hazard_sbus_rx_replay_smoke`: PASS (`uart_rbr_read_count == 1`)
- Full `./scripts/regress.sh`: 31/31 PASS (`soc.list`)

## Regression Evidence

```bash
./scripts/regress.sh
```

Latest full TORV regress: **31/31 PASS** (includes `hazard_ibus_insn_dup`, `hazard_ibus_store_dup`, `hazard_sbus_rx_replay_smoke`).

## Code Locations

- `rtl/torv_soc_top.sv`: TORV address map and UART APB window.
- `rtl/torv_ahb_sram.sv`: low-16-bit SRAM indexing compatibility with legacy tests.
- `rtl/hazard_unit.sv`: `stall_front` / BYG-006 insn-dup fix.
- `rtl/rv32im_core.sv`: load/store replay guard on DBUS/SBUS valid (BYG-005).
- `rtl/torv_soc_top.sv`: `uart_rbr_read_count` for directed RX replay tests; see file header for AHB `HSEL`/mux caveats vs pipelined masters.
- `sim/tb_torv_soc.sv`: TORV single testbench, replay expectation, directed bus stalls.
- `tests/periph/apb_uart_sv/*.S`: UART base at `0x4000_1000`.
- `tests/core/asm/hazard_sbus_replay_smoke.S`: TORV UART replay smoke.
