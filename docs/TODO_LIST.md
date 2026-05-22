# open_rv32m optimization backlog

Items deferred from the 2026-05 review (not in the current documentation/regression pass).

## Microarchitecture / IPC

- [ ] Core-only zero-wait SRAM bench to separate AHB stall vs pipeline stall
- [ ] 1-cycle local IMEM/DMEM or small caches on AHB
- [ ] Branch early resolve / lower flush penalty
- [ ] Simplify `stall_front` to global EX/MEM freeze + unified retire in `rv32im_core` (re-verify 32/32)
- [ ] RV32M DIV: DesignWare / macro / stub top for DC exploration

## ISA / software

- [ ] Minimal trap / CSR path or syscall stub for C runtime
- [ ] `crt0` + linker scripts + CoreMark/Dhrystone for published IPC

## Verification

- [ ] Random IBUS/DBUS `HREADY` stall generator (constrained length)
- [ ] SVA on hazard/replay (`stall_id_ex` ⇒ `stall_pc`, no MMIO replay)
- [ ] Optional “golden RTL” negative regress for pre-BYG-006 behavior

## SoC

- [ ] Pipelined AHB master: latched `HSEL` / data-phase mux (see `torv_soc_top` header)
- [ ] `ibus_valid` deassert for low-power or multi-master
- [ ] Plusarg alias `stall_ibus_during_mem_read` (TB already arms on read via `mem_bus_active`)

## Synthesis / PPA

- [ ] Re-run DC with realistic clock uncertainty / wire load
- [ ] Area breakdown: regfile vs `muldiv_unit`; pipelined multiplier option

## CI / automation

- [ ] GitHub/GitLab CI: `fetch_ip.sh` + `regress.sh` smoke + `deep_hazard.list`
- [ ] Nightly full `soc.list` + archive `perf_summary.csv`
