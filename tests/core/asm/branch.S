# =============================================================================
# branch.S — conditional branches: BEQ/BNE/BLT/BGE/BLTU/BGEU taken and not-taken
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 5
  addi x2, x0, 5
  addi x3, x0, 7
  addi x4, x0, -1

  beq  x1, x2, 1f
  jal  x0, fail
1:
  beq  x1, x3, fail

  bne  x1, x3, 2f
  jal  x0, fail
2:
  bne  x1, x2, fail

  blt  x4, x1, 3f
  jal  x0, fail
3:
  blt  x1, x4, fail

  bge  x1, x4, 4f
  jal  x0, fail
4:
  bge  x4, x1, fail

  bltu x1, x4, 5f       # 5 < 0xffffffff unsigned
  jal  x0, fail
5:
  bltu x4, x1, fail

  bgeu x4, x1, 6f
  jal  x0, fail
6:
  bgeu x1, x4, fail

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
