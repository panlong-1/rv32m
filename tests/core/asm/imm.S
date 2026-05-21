# =============================================================================
# imm.S — immediates: sign-extended ADDI, xori/ori/andi, slti/sltiu, LUI split check
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, -1
  addi x2, x1, 1
  bne  x2, x0, fail

  xori x3, x1, -1
  bne  x3, x0, fail
  ori  x4, x0, 0x55
  andi x5, x4, 0x0f
  addi x6, x0, 5
  bne  x5, x6, fail

  slti x7, x1, 0
  addi x8, x0, 1
  bne  x7, x8, fail
  sltiu x9, x1, 1
  bne  x9, x0, fail

  lui  x10, 0x12345
  srli x11, x10, 12
  lui  x12, 0x12
  addi x12, x12, 0x345
  bne  x11, x12, fail

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
