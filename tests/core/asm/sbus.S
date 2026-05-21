# =============================================================================
# sbus.S — SBUS (0x4000_0000): SW/LW, SB/LBU (via addr_decode use_sbus)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x40000

  addi x1, x0, 0x5a
  sw   x1, 16(x3)
  lw   x2, 16(x3)
  bne  x2, x1, fail

  addi x4, x0, -1
  sb   x4, 20(x3)
  lbu  x5, 20(x3)
  addi x6, x0, 255
  bne  x5, x6, fail

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
