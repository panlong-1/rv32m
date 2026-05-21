# =============================================================================
# bus_mix_dbus_sbus.S — interleaved DBUS(0x20000000) and SBUS(0x40000000) traffic
# Goal: LSU routing + dual-bus vs IBUS stall/hazard (typical multi-port AHB sim stress)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x20000
  lui  x11, 0x40000

  addi x1, x0, 0x12
  sw   x1, 0(x10)
  lw   x2, 0(x10)
  bne  x2, x1, fail

  sw   x2, 32(x11)
  lw   x3, 32(x11)
  bne  x3, x2, fail

  addi x4, x0, 0x34
  sw   x4, 36(x11)
  lw   x5, 36(x11)
  sw   x5, 4(x10)
  lw   x6, 4(x10)
  bne  x6, x4, fail

  lw   x7, 32(x11)
  bne  x7, x1, fail

  addi x8, x0, 100
  sw   x8, 8(x10)
  lw   x9, 8(x10)
  sw   x9, 40(x11)
  lw   x12, 40(x11)
  bne  x12, x8, fail

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
