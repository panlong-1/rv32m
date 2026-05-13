# =============================================================================
# perf_mul_loop.S - RV32M multiply loop benchmark
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 16
  addi x2, x0, 3
  addi x3, x0, 7
  addi x4, x0, 0

loop:
  mul  x5, x2, x3
  add  x4, x4, x5
  addi x1, x1, -1
  bne  x1, x0, loop

  addi x6, x0, 336
  bne  x4, x6, fail

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
