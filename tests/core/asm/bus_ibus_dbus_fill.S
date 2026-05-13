# =============================================================================
# bus_ibus_dbus_fill.S — 连续 ADDI 拉长取指段，再对 DBUS 多字 SW/LW（IF/MEM 重叠压力）
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x20000

  addi x1, x0, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1
  addi x1, x1, 1

  sw   x1, 0(x3)
  lw   x2, 0(x3)
  bne  x2, x1, fail

  addi x4, x0, 0x55
  sw   x4, 4(x3)
  lw   x5, 4(x3)
  bne  x5, x4, fail

  addi x6, x0, 0xaa
  sw   x6, 8(x3)
  lw   x7, 8(x3)
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
