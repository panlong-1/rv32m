# =============================================================================
# replay_div_store.S — AHB replay: SW to UART THR then DIV (div_busy holds MEM)
#
# PULP UART THR push count checked in tb_torv_soc (uart_thr_push_count).
# Requires replay_div_store.plusargs (+replay_expect=1).
# =============================================================================
  .section .text.init
  .globl _start

  .equ UART_BASE, 0x40001000

_start:
  lui  x10, %hi(UART_BASE)
  addi x10, x10, %lo(UART_BASE)
  addi x1, x0, 99
  addi x2, x0, 7
  addi x11, x0, 0x55

  sw   x11, 0(x10)
  div  x3, x1, x2

  addi x12, x0, 48
wait_div:
  addi x12, x12, -1
  bne  x12, x0, wait_div

  addi x6, x3, 0
  addi x7, x0, 14
  bne  x6, x7, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 6
  sw   x21, 0(x20)
1:
  jal  x0, 1b
