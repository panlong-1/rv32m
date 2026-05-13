# =============================================================================
# loadstore.S — DBUS（0x2000_0000）：SW/LW、LB/LBU、LH/LHU、SB/SH 对齐访存
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x20000

  lui  x1, 0x11223
  addi x1, x1, 0x344
  sw   x1, 0(x3)
  lw   x2, 0(x3)
  bne  x2, x1, fail

  lb   x4, 3(x3)
  addi x5, x0, 0x11
  bne  x4, x5, fail
  lbu  x6, 2(x3)
  addi x7, x0, 0x22
  bne  x6, x7, fail

  addi x8, x0, -1
  sb   x8, 4(x3)
  lb   x9, 4(x3)
  bne  x9, x8, fail
  lbu  x10, 4(x3)
  addi x11, x0, 255
  bne  x10, x11, fail

  addi x12, x0, -2
  sh   x12, 6(x3)
  lh   x13, 6(x3)
  bne  x13, x12, fail
  lhu  x14, 6(x3)
  lui  x15, 0x10
  addi x15, x15, -2
  bne  x14, x15, fail

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
