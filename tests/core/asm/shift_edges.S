# =============================================================================
# shift_edges.S — shift edges: slli 31, srli/srai, variable shift low 5 bits (40→8)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 1
  slli x2, x1, 31
  lui  x3, 0x80000
  bne  x2, x3, fail

  srli x4, x3, 31
  bne  x4, x1, fail

  srai x5, x3, 31
  addi x6, x0, -1
  bne  x5, x6, fail

  addi x7, x0, 40
  sll  x8, x1, x7       # shift amount uses low 5 bits, 40 -> 8
  addi x9, x0, 256
  bne  x8, x9, fail
  srl  x10, x9, x7
  bne  x10, x1, fail

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
