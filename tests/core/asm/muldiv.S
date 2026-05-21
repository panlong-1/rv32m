# =============================================================================
# muldiv.S — RV32M: MULH/MULHU/MULHSU, signed DIV/REM, DIVU/REMU, divide-by-zero, overflow edges
# =============================================================================
  .section .text.init
  .globl _start

_start:
  # Shared multiplier variants
  addi x1, x0, -1
  addi x2, x0, 2

  mulh x3, x1, x2       # high(-1 * 2) = -1
  bne  x3, x1, fail

  mulhu x4, x1, x2      # high(0xffff_ffff * 2) = 1
  addi x5, x0, 1
  bne  x4, x5, fail

  mulhsu x6, x1, x2     # high(signed -1 * unsigned 2) = -1
  bne  x6, x1, fail

  # Multi-cycle divider normal cases
  addi x10, x0, 20
  addi x11, x0, 3
  div  x12, x10, x11
  addi x13, x0, 6
  bne  x12, x13, fail
  rem  x14, x10, x11
  addi x15, x0, 2
  bne  x14, x15, fail

  addi x16, x0, -20
  div  x17, x16, x11
  addi x18, x0, -6
  bne  x17, x18, fail
  rem  x19, x16, x11
  addi x20, x0, -2
  bne  x19, x20, fail

  divu x21, x10, x11
  bne  x21, x13, fail
  remu x22, x10, x11
  bne  x22, x15, fail

  # Divide-by-zero corner cases.
  div  x23, x10, x0
  addi x24, x0, -1
  bne  x23, x24, fail
  rem  x25, x10, x0
  bne  x25, x10, fail
  divu x26, x10, x0
  bne  x26, x24, fail
  remu x27, x10, x0
  bne  x27, x10, fail

  # Signed overflow: 0x80000000 / -1.
  lui  x28, 0x80000
  div  x29, x28, x24
  bne  x29, x28, fail
  rem  x30, x28, x24
  bne  x30, x0, fail

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
