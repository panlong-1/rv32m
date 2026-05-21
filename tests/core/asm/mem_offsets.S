# =============================================================================
# mem_offsets.S — DBUS positive/negative offsets: base x3=0x20000040, e.g. -4/+8/-1
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x20000
  addi x3, x3, 64

  addi x1, x0, 11
  sw   x1, -4(x3)
  lw   x2, -4(x3)
  bne  x2, x1, fail

  addi x4, x0, 22
  sw   x4, 8(x3)
  lw   x5, 8(x3)
  bne  x5, x4, fail

  addi x6, x0, 0x7f
  sb   x6, -1(x3)
  lb   x7, -1(x3)
  bne  x7, x6, fail

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
