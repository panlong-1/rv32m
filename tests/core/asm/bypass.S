# =============================================================================
# bypass.S — 前递：EX 链、寄存器移位、load→ALU 使用 DBUS 0x2000_0000
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 1
  addi x2, x1, 2
  addi x3, x2, 3
  addi x4, x3, 4
  addi x5, x0, 10
  bne  x4, x5, fail

  add  x6, x4, x5
  sub  x7, x6, x4
  bne  x7, x5, fail

  addi x8, x0, 3
  sll  x9, x8, x8
  addi x10, x0, 24
  bne  x9, x10, fail

  lui  x11, 0x20000
  sw   x10, 0(x11)
  lw   x12, 0(x11)
  addi x13, x12, 1
  addi x14, x0, 25
  bne  x13, x14, fail

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
