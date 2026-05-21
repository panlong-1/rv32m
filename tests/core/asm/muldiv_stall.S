# =============================================================================
# muldiv_stall.S — after multi-cycle DIV/REM mix immediates/MUL (stall + forwarding)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 99
  addi x2, x0, 7

  div  x3, x1, x2
  addi x4, x3, 1
  addi x5, x0, 15
  bne  x4, x5, fail

  rem  x6, x1, x2
  addi x7, x0, 1
  bne  x6, x7, fail

  mul  x8, x3, x2
  add  x9, x8, x6
  bne  x9, x1, fail

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
