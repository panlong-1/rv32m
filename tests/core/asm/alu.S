# =============================================================================
# alu.S — ALU: add/sub, SLT/SLTU/SLTI/SLTIU, logic, barrel shifts (I and R types)
# No memory base (registers only); ends via tohost
# =============================================================================
  .section .text.init
  .globl _start

_start:
  # add / sub share the ALU add-sub datapath
  addi x1, x0, 17
  addi x2, x0, 5
  add  x3, x1, x2
  addi x4, x0, 22
  bne  x3, x4, fail
  sub  x5, x1, x2
  addi x6, x0, 12
  bne  x5, x6, fail

  # signed and unsigned set-less-than reuse subtract/carry results
  addi x7, x0, -1
  slt  x8, x7, x0
  addi x9, x0, 1
  bne  x8, x9, fail
  sltu x10, x7, x0
  bne  x10, x0, fail
  slti x11, x7, 0
  bne  x11, x9, fail
  sltiu x12, x7, 1
  bne  x12, x0, fail

  # logicals
  addi x13, x0, 0x55
  addi x14, x0, 0x0f
  and  x15, x13, x14
  addi x16, x0, 0x05
  bne  x15, x16, fail
  or   x17, x13, x14
  addi x18, x0, 0x5f
  bne  x17, x18, fail
  xor  x19, x13, x14
  addi x20, x0, 0x5a
  bne  x19, x20, fail

  # explicit five-stage barrel shifter
  addi x21, x0, 1
  slli x22, x21, 5
  addi x23, x0, 32
  bne  x22, x23, fail
  srli x24, x22, 3
  addi x25, x0, 4
  bne  x24, x25, fail
  addi x26, x0, -8
  srai x27, x26, 1
  addi x28, x0, -4
  bne  x27, x28, fail

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
