# TORV backlog

Open items as of `v0.7-open-flow`. Completed items are kept at the end for reference.

## Timing / implementation (IHP SG13G2)

- [ ] Close the 10 ns slow corner (1.08 V / 125 °C, currently −0.73 ns on 26 endpoints).
  - [ ] Pre-select the EX/MEM forwarding value in EX (PC+4 vs ALU) so `ex_mem_wb_sel` leaves
        the operand → branch target / AGU → AHB output paths. Watch the MUL → EX/MEM path,
        which has ≈ 0.07 ns slack at the slow corner.
  - [ ] Replace the generic 2 ns I/O budget in `librelane/constraints.sdc` with the real SoC
        interconnect and SRAM wrapper timing.
  - [ ] Alternatively, sign off the slow corner at 12.5 ns (80 MHz).
- [ ] Implement `torv_soc` with the three IHP SRAM macros (macro placement, PDN, halos)
      for a full SoC GDS. Size the SRAMs to the tape-out area budget (one 1024x32 macro is
      ≈ 140k µm²).
- [ ] Switching-activity-based power (SAIF/VCD from regression) instead of default activity.
- [ ] Look at the 141 max-fanout warnings (soft constraint) and the `hclk` fanout of ~1700 sinks.

## Microarchitecture / IPC

- [ ] Branch prediction or early resolution (taken branch costs 2 cycles).
- [ ] Single-cycle MUL again, if timing allows (for example by retiming the operand registers
      into ID).
- [ ] Simplify `stall_front` toward a global EX/MEM freeze plus unified retire (re-verify the
      full regression).

## ISA / software

- [ ] Minimal trap / CSR path, or a syscall stub for a C runtime.
- [ ] `crt0` + C linker script (`.data`/`.bss`/stack in DMEM) + CoreMark/Dhrystone for
      published IPC.

## Verification

- [ ] Random IBUS/DBUS/SBUS `HREADY` stall generator (constrained length).
- [ ] SVA on the hazard/replay rules (`stall_id_ex` ⇒ `stall_pc`, no MMIO replay); SymbiYosys.
- [ ] Plusarg alias `stall_ibus_during_mem_read` (the TB already arms on reads via
      `mem_bus_active`).

## CI / automation

- [ ] CI: `fetch_ip.sh` + `regress.sh` smoke + `deep_hazard.list` (needs the IHP PDK SRAM
      models in the CI image).
- [ ] Nightly full `soc.list`, archiving `perf_summary.csv`; weekly `make -C librelane flow`.

## Done

- [x] Pipelined AHB-Lite IBUS (one fetch per cycle) — `v0.2-ibus-pipe`
- [x] Pipelined DBUS/SBUS with zero-wait loads/stores — `v0.3-dbus-pipe`
- [x] SoC memories on IHP SG13G2 SRAM macros — `v0.4-ihp-sram`
- [x] Open-source synthesis and RTL-to-GDS on IHP SG13G2 (LibreLane); DRC/LVS/antenna clean
- [x] Slow-corner timing work: AGU, two-cycle MUL, Booth, post-GRT repair, registered
      forwarding — `v0.5-timing`, `v0.6-fwd-reg`
- [x] Repository reduced to open-source tools only — `v0.7-open-flow`
