# =============================================================================
# jump.S — JAL / JALR: link register non-zero, %hi/%lo target addresses
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 0
  jal  x5, jal_target
  jal  x0, fail

after_jal:
  lui  x6, %hi(jalr_target + 1)
  addi x6, x6, %lo(jalr_target + 1)
  jalr x7, 0(x6)
  jal  x0, fail

after_jalr:
  addi x8, x0, 2
  bne  x1, x8, fail
  beq  x5, x0, fail
  beq  x7, x0, fail
  jal  x0, pass

jal_target:
  addi x1, x1, 1
  jal  x0, after_jal

jalr_target:
  addi x1, x1, 1
  jal  x0, after_jalr

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
