# TORV SoC

**TORV** = **T**orino **O**pen **R**ISC-**V** — open-source RV32IM platform for the PoliTO RISC-V student team.

## RTL top

| Module | Role |
|--------|------|
| `torv_soc_top` | SoC integration (CPU, SRAM, AHB→APB, UART) |
| `rv32im_ahb_top` | RV32IM + three AHB-Lite masters |
| `torv_ahb_sram` | AHB-Lite SRAM slave |
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

Legacy `--target core|ahb` and `tb_rv32im_top` / `tb_rv32im_ahb_top` are deprecated.

## Memory map (SBUS)

| Region | Address |
|--------|---------|
| SBUS SRAM | `0x0000_0000` – `0x0000_FFFF` |
| SBUS data SRAM alias | `0x4000_0000` – `0x4000_0FFF` |
| APB UART | `0x4000_1000` – `0x4000_1FFF` |
| tohost | `0xF000_0000` (TB monitor) |

## Debug Notes

Integration bug history is tracked in `docs/bugs/byg_torv_soc_debug.md`.
