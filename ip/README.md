# Third-party IP (simulation only)

TORV SoC pulls these third-party files via `ip/filelist.f`.

| IP | Source | License |
|----|--------|---------|
| `AHB_APB_BRIDGE` | [shalan/SoCBUS](https://github.com/shalan/SoCBUS) | Apache-2.0 |
| `apb_uart_sv` | [pulp-platform/apb_uart_sv](https://github.com/pulp-platform/apb_uart_sv) (`pulpinov1`) | Solderpad SHL-0.51 |

First SoC simulation run invokes `scripts/fetch_ip.sh` if tarballs are missing.

## Unified commands

```bash
source scripts/open_rv.sh
./scripts/run_case.sh tests/periph/apb_uart_sv/uart_smoke.S
./scripts/regress.sh
```

`--target core|ahb` only changes the regression case list file; simulation always uses TORV SoC (`tb_torv_soc`).

Wiring is in `rtl/torv_soc_top.sv` (no `ip/bus/` or wrapper modules in this repo).

## Fetch

```bash
./scripts/fetch_ip.sh
```

Patches applied during fetch: SoCBUS include paths, trim broken `ahb_util.vh` tail, Verilator port renames (`penable_r`, `paddr_r`, `pwrite_r`). See `scripts/fetch_ip.sh`.

## Tests

| Path | Role |
|------|------|
| `tests/periph/apb_uart_sv/` | UART smoke + AHB replay stress |
| `tests/core/asm/hazard_sbus_replay_smoke.S` | TORV replay check |
