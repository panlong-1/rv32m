# =============================================================================
# perf_loadstore_loop.S - DBUS load/store loop benchmark
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 32
  lui  x10, 0x1
  addi x3, x0, 1
  addi x5, x0, 0

loop:
  sw   x3, 0(x10)
  lw   x4, 0(x10)
  add  x5, x5, x4
  addi x3, x3, 1
  addi x10, x10, 4
  addi x1, x1, -1
  bne  x1, x0, loop

  addi x6, x0, 528
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
