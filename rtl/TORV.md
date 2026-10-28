# TORV SoC

**TORV** = **T**orino **O**pen **R**ISC-**V** — open-source RV32IM platform for the PoliTO RISC-V student team.

## RTL top

| Module | Role |
|--------|------|
| `torv_soc_top` | SoC integration (CPU, SRAM, AHB→APB, UART) |
| `rv32im_ahb_top` | RV32IM + three AHB-Lite masters |
| `torv_ahb_sram` | Zero-wait AHB-Lite wrapper around an IHP SG13G2 SRAM macro |
| `AHB_APB_BRIDGE` | SoCBUS (third-party) |
| `apb_uart_sv` | PULP UART @ `0x4000_1000` |

## Simulation (single entry)

```bash
source scripts/open_rv.sh
./scripts/run_case.sh tests/core/asm/smoke.S
./scripts/regress.sh
```

- Testbench: `sim/tb_torv_soc.sv`
- Build dir: `build/sim/soc/<case>/`
- Case list: `regress/cases/soc.list`

Legacy `--target core|ahb` only selects an older case list; simulation always uses `tb_torv_soc`.

## Memory map (SBUS)

| Region | Address |
|--------|---------|
| SBUS data SRAM (4 KiB) | `0x4000_0000` – `0x4000_0FFF` |
| APB UART | `0x4000_1000` – `0x4000_1FFF` |
| tohost | `0xF000_0000` (TB monitor) |

Full map: [docs/torv_address_map.md](../docs/torv_address_map.md). The IBUS and DBUS SRAMs are
4 KiB each (`IMEM_WORDS` / `DMEM_WORDS`).

## Implementation

`rv32im_ahb_top` (the core and its AHB masters) goes through RTL-to-GDS on IHP SG13G2 with
LibreLane (`make -C librelane flow`). The SoC level with the SRAM macros is not implemented
yet. See [docs/open_source_flow.md](../docs/open_source_flow.md).

## Debug Notes

Integration bug history is tracked in `docs/bugs/byg_torv_soc_debug.md`.
