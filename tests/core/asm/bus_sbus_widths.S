# =============================================================================
# bus_sbus_widths.S — SBUS only: SW/LW, SH/LH/LHU, SB/LB/LBU (half/byte sign extension)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x40000

  lui  x1, 0xABCDE
  addi x1, x1, 0x678
  sw   x1, 0(x3)
  lw   x2, 0(x3)
  bne  x2, x1, fail

  addi x4, x0, -222
  sh   x4, 8(x3)
  lh   x5, 8(x3)
  bne  x5, x4, fail
  lhu  x6, 8(x3)
  lui  x7, 0x10
  addi x7, x7, -222
  bne  x6, x7, fail

  addi x8, x0, -3
  sb   x8, 12(x3)
  lb   x9, 12(x3)
  bne  x9, x8, fail
  lbu  x10, 12(x3)
  addi x11, x0, 253
  bne  x10, x11, fail

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
