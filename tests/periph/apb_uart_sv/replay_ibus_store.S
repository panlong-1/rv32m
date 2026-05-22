# =============================================================================
# replay_ibus_store.S — IBUS stall during UART THR write (supplemental replay case)
# Software spins; TB checks uart_thr_push_count on timeout (+replay_expect=1).
# =============================================================================
  .section .text.init
  .globl _start

  .equ UART_BASE, 0x40001000

_start:
  lui  x10, %hi(UART_BASE)
  addi x10, x10, %lo(UART_BASE)
  addi x11, x0, 0x55
  sw   x11, 0(x10)

spin:
  jal  x0, spin
