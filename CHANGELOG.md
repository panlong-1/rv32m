# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions from v0.8.0 follow
[SemVer](https://semver.org). Older, more detailed session notes are in `docs/changelog/`.

## [Unreleased]

### Added
- `scripts/lint.sh`: Verilator lint of the hardened block (`torv_cpu`), used by CI.
- GitHub Actions CI (`lint`, `regress`), `CONTRIBUTING.md`, `CODEOWNERS`, issue and PR templates.

## [0.8.0]

### Changed
- Project renamed from `rv32m` / `open_rv32m` to **TORV** (Torino Open RISC-V), maintained by the
  SemiTO-V ASIC Task Force. No functional change: regression results, cycle counts and synthesis
  QoR are identical to v0.7.1.

| Before v0.8.0 | From v0.8.0 |
|---|---|
| `rv32im_ahb_top` (LibreLane `DESIGN_NAME`, GDS/DEF) | `torv_cpu` |
| `rv32im_core` | `torv_core` |
| `rv32im_ahb_fetch`, `rv32im_ahb_dport` | `torv_ahb_fetch`, `torv_ahb_dport` |
| `torv_soc_top` | `torv_soc` |
| `alu_control` | `torv_alu_ctrl` |
| `alu`, `decoder`, `imm_gen`, `regfile`, `pc_unit`, `forwarding_unit`, `hazard_unit`, `muldiv_unit`, `lsu`, `addr_decode` | `torv_<name>` |
| `rtl/bus_if.sv` | `rtl/torv_bus_types.sv` |
| `scripts/open_rv.sh`, `scripts/open_rv.local.sh` | `scripts/env.sh`, `scripts/env.local.sh` |
| `RV32M_*` environment variables | `TORV_*` |

Instance names (`u_cpu`, `u_core`, `u_rf`, ...) did not change.

### Deprecated
- `scripts/open_rv.sh`, `scripts/open_rv.local.sh` and `RV32M_*` variables still work with a
  warning; they will be removed in v0.9.0.

## Earlier releases (as `rv32m`)

| Tag | Summary |
|---|---|
| `v0.7.1-readme-figs` | README architecture diagrams, back-end data and layout figures |
| `v0.7-open-flow` | Open-source-only repository, `make -C librelane flow`, documentation refresh |
| `v0.6-fwd-reg` | Registered forwarding selects, pre-selected MEM/WB result |
| `v0.5-timing` | Slow-corner timing: AGU, 2-cycle MUL, Booth, post-GRT repair |
| `v0.4-ihp-sram` | TORV SoC SRAMs on IHP SG13G2 macros (zero-wait wrapper) |
| `v0.3-dbus-pipe` | Pipelined DBUS/SBUS (zero-wait loads/stores) |
| `v0.2-ibus-pipe` | Pipelined IBUS fetch (IPC up to ~0.8) |
| `v0.1-baseline` | Baseline before IHP synthesis flow and bus pipelining (IPC ~0.2) |
