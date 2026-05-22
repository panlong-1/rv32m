# apb_uart_sv (PULP)

Map: TORV SBUS `0x4000_1000` (12-bit APB window). Wired in `rtl/torv_soc_top.sv` through SoCBUS `AHB_APB_BRIDGE`.

| Case | File | Purpose |
|------|------|---------|
| `uart_smoke` | `uart_smoke.S` | One THR write; expect `uart_thr_push_count == 1` |
| `replay_div_store` | `replay_div_store.S` | DIV in EX while MEM store stalls; replay detect |
| `replay_ibus_store` | `replay_ibus_store.S` | IBUS stall during MEM store (`replay_ibus_store.plusargs`) |

Plusargs (sibling `*.plusargs`, auto-loaded): `+replay_expect=1`, optional `+stall_ibus_during_mem_write=N`.

```bash
./scripts/run_case.sh tests/periph/apb_uart_sv/uart_smoke.S
./scripts/regress.sh --case-list regress/cases/periph_replay.list
```

Replay proof in TORV SoC: `tests/core/asm/hazard_sbus_replay_smoke.S`.
