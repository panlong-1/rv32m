# =============================================================================
# perf_branch_loop.S - tight taken branch loop benchmark
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 128
  addi x2, x0, 0

loop:
  addi x2, x2, 1
  addi x1, x1, -1
  bne  x1, x0, loop

  addi x3, x0, 128
  bne  x2, x3, fail

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
