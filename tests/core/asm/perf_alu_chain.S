# =============================================================================
# perf_alu_chain.S - dependent ALU chain benchmark
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 0
  addi x2, x0, 64
  addi x3, x0, 1

loop:
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  add  x1, x1, x3
  addi x2, x2, -1
  bne  x2, x0, loop

  addi x4, x0, 512
  bne  x1, x4, fail

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
