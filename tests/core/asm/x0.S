# =============================================================================
# x0.S — x0 hardwired: writes ignored, reads as 0; lw x0 does not alter x0; other GPRs unaffected
# DBUS: 0x2000_0000
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x20000

  addi x0, x0, 123
  bne  x0, x0, fail

  addi x1, x0, 77
  add  x0, x1, x1
  bne  x0, x0, fail

  sw   x1, 0(x3)
  lw   x0, 0(x3)
  bne  x0, x0, fail

  addi x2, x0, 77
  bne  x1, x2, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 2
  sw   x21, 0(x20)
1:
  jal  x0, 1b
