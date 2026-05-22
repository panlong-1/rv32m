# =============================================================================
# uart_smoke.S — one THR write to PULP apb_uart_sv @ 0x4000_0000 (AHB/APB)
# TB checks uart_thr_push_count == 1 on tohost PASS (+replay_expect=1 optional).
# =============================================================================
  .section .text.init
  .globl _start

  .equ UART_BASE, 0x40001000

_start:
  lui  x10, %hi(UART_BASE)
  addi x10, x10, %lo(UART_BASE)
  addi x11, x0, 0x55

  sw   x11, 0(x10)
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b
