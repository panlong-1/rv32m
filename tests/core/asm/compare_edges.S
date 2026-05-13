# =============================================================================
# compare_edges.S — 比较与分支角例：0x80000000、-1 与 slt/sltu/blt/bge/bltu/bgeu
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x1, 0x80000
  addi x2, x0, -1
  addi x3, x0, 1

  slt  x4, x1, x0
  bne  x4, x3, fail
  slt  x5, x2, x1
  bne  x5, x0, fail
  sltu x6, x1, x2
  bne  x6, x3, fail
  sltu x7, x2, x1
  bne  x7, x0, fail

  blt  x1, x0, 1f
  jal  x0, fail
1:
  bge  x0, x1, 2f
  jal  x0, fail
2:
  bltu x1, x2, 3f
  jal  x0, fail
3:
  bgeu x2, x1, 4f
  jal  x0, fail
4:

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
