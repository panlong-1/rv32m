# Peripheral tests (by IP)

Each third-party peripheral has its own directory under `tests/periph/`.  
Simulation still uses the **unified entry** (`run_case.sh` / `regress.sh`); only the asm path changes.

```text
tests/periph/
  apb_uart_sv/     # PULP apb_uart_sv @ 0x4000_1000 (via SoCBUS AHB_APB_BRIDGE)
  README.md
```

## Commands

```bash
source scripts/open_rv.sh

# Single case (+<case>.plusargs in the same IP directory)
./scripts/run_case.sh tests/periph/apb_uart_sv/uart_smoke.S

# TORV SoC regression (regress/cases/soc.list)
./scripts/regress.sh

# Replay subset
./scripts/regress.sh --case-list regress/cases/periph_replay.list
```

CPU memory-replay verification in TORV SoC:

```bash
./scripts/run_case.sh tests/core/asm/hazard_sbus_replay_smoke.S
```

See `ip/README.md` for third-party fetch and licenses.
