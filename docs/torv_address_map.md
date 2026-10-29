# TORV SoC address map

Reference for `torv_soc` simulation and asm tests. The CPU uses `torv_addr_decode` in the core for DBUS vs SBUS routing; the SoC muxes SBUS into SRAM, APB UART, or (testbench-only) tohost.

## CPU bus routing (`torv_addr_decode`)

| Address range | Master | Typical use |
|---------------|--------|-------------|
| `0x0000_0000` – `0x3FFF_FFFF` (not SBUS window) | **DBUS** | Data SRAM (`0x2000_0000` in core tests) |
| `0x4000_0000` – `0x4FFF_FFFF` | **SBUS** | SoC SBUS SRAM + peripherals |
| `0xF000_0000` – `0xFFFF_FFFF` | **SBUS** | Testbench tohost (not decoded in DUT) |

## SoC slaves (`torv_soc`)

| Bus | Region | Size / note | Device |
|-----|--------|-------------|--------|
| IBUS | `0x0000_0000` – `0x0000_0FFF` | 4 KiB (`IMEM_WORDS`=1024), aliases above | Instruction SRAM (`u_i_sram`) |
| DBUS | any DBUS address, e.g. `0x2000_0000` | 4 KiB (`DMEM_WORDS`=1024), aliases above | Data SRAM (`u_d_sram`) |
| SBUS | `0x4000_0000` – `0x4000_0FFF` | 4 KiB (`SBMEM_WORDS`=1024) | SBUS data SRAM (`u_s_sram`), core asm `lui 0x40000` |
| SBUS | `0x4000_1000` – `0x4000_1FFF` | 4 KiB page | PULP UART via `AHB_APB_BRIDGE` (APB) |
| SBUS | `0xF000_0000` | word | **Simulation only**: `tb_torv_soc` watches stores for pass/fail |

All three SRAMs are IHP SG13G2 `RM_IHPSG13_1P_<WORDS>x32_c2_bm_bist` macros behind the zero-wait AHB-Lite wrapper `torv_ahb_sram` (`WORDS` = 256, 512 or 1024; one macro each). They are word-indexed by the low address bits and alias above their size. The SBUS SRAM is not selected for the UART page or `0xF000_0000`, so it does not alias them.

UART is intentionally at **`0x4000_1000`** so it does not alias core SBUS tests at **`0x4000_0000`**.

## Asm test conventions

| Symbol | Value | Bus |
|--------|-------|-----|
| DMEM base | `0x2000_0000` | DBUS (`hazard.S`, `loadstore.S`, `perf_loadstore_loop.S`) |
| SBUS SRAM | `0x4000_0000` | SBUS (`sbus.S`, `hazard_ibus_*.S` stores/loads) |
| tohost | `0xF000_0000` | Monitored by TB (not an on-chip peripheral) |

## Related files

- `rtl/torv_soc.sv` — parameter `UART_APB_BASE`, header comments
- `rtl/torv_addr_decode.sv` — core DBUS/SBUS select
- `rtl/torv_ahb_sram.sv` — AHB-Lite wrapper for the IHP SRAM macro (write buffer, read merge)
- `tests/core/asm/sram_wbuf.S` — directed test for the wrapper's write buffer / read merge
- `docs/bugs/byg_torv_soc_debug.md` — BYG-001 UART vs SBUS collision
