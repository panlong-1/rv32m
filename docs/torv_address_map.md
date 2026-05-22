# TORV SoC address map

Reference for `torv_soc_top` simulation and asm tests. The CPU uses `addr_decode` in the core for DBUS vs SBUS routing; the SoC muxes SBUS into SRAM, APB UART, or (testbench-only) tohost.

## CPU bus routing (`addr_decode`)

| Address range | Master | Typical use |
|---------------|--------|-------------|
| `0x0000_0000` – `0x3FFF_FFFF` (not SBUS window) | **DBUS** | Data SRAM (`0x2000_0000` in core tests) |
| `0x4000_0000` – `0x4FFF_FFFF` | **SBUS** | SoC SBUS SRAM + peripherals |
| `0xF000_0000` – `0xFFFF_FFFF` | **SBUS** | Testbench tohost (not decoded in DUT) |

## SoC SBUS slaves (`torv_soc_top`)

| Region | Size / note | Device |
|--------|-------------|--------|
| `0x0000_0000` – `0x0000_FFFF` | 64 KiB, index `[15:0]` | IBUS instruction SRAM (`u_i_sram`) |
| (DBUS) | 64 KiB | DMEM (`u_d_sram`), addresses as issued by core |
| `0x4000_0000` – `0x4000_FFFF` | 64 KiB, index `[15:0]` | SBUS data SRAM (`u_s_sram`) — core asm `lui 0x40000` |
| `0x4000_1000` – `0x4000_1FFF` | 4 KiB | PULP UART via `AHB_APB_BRIDGE` (APB) |
| `0xF000_0000` | word | **Simulation only**: `tb_torv_soc` watches stores for pass/fail |

UART is intentionally at **`0x4000_1000`** so it does not alias core SBUS tests at **`0x4000_0000`**.

## Asm test conventions

| Symbol | Value | Bus |
|--------|-------|-----|
| DMEM base | `0x2000_0000` | DBUS (`hazard.S`, `loadstore.S`, `perf_loadstore_loop.S`) |
| SBUS SRAM | `0x4000_0000` | SBUS (`sbus.S`, `hazard_ibus_*.S` stores/loads) |
| tohost | `0xF000_0000` | Monitored by TB (not an on-chip peripheral) |

## Related files

- `rtl/torv_soc_top.sv` — parameter `UART_APB_BASE`, header comments
- `rtl/addr_decode.sv` — core DBUS/SBUS select
- `rtl/torv_ahb_sram.sv` — low 16-bit address indexing for legacy test compatibility
- `docs/bugs/byg_torv_soc_debug.md` — BYG-001 UART vs SBUS collision
