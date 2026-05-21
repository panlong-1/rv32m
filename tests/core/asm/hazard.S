# =============================================================================
# hazard.S — hazards: load-use (ALU/branch), narrow load sign/zero extend, load→store forwarding
# DBUS base: 0x2000_0000 (not SBUS)
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x3, 0x20000        # DBUS data region base

  # lw -> add immediate consumer
  addi x1, x0, 42
  sw   x1, 0(x3)
  lw   x2, 0(x3)
  add  x4, x2, x2
  addi x5, x0, 84
  bne  x4, x5, fail

  # lw -> branch immediate consumer
  lw   x6, 0(x3)
  addi x7, x0, 42
  beq  x6, x7, 1f
  jal  x0, fail
1:

  # byte load sign/zero extension -> branch
  addi x8, x0, -1
  sb   x8, 4(x3)
  lb   x9, 4(x3)
  addi x10, x0, -1
  bne  x9, x10, fail
  lbu  x11, 4(x3)
  addi x12, x0, 255
  bne  x11, x12, fail

  # halfword load sign/zero extension -> branch
  addi x13, x0, -2
  sh   x13, 6(x3)
  lh   x14, 6(x3)
  addi x15, x0, -2
  bne  x14, x15, fail
  lhu  x16, 6(x3)
  lui  x17, 0x10
  addi x17, x17, -2     # 0x0000_fffe
  bne  x16, x17, fail

  # load -> store data forwarding
  lw   x18, 0(x3)
  sw   x18, 12(x3)
  lw   x19, 12(x3)
  bne  x19, x1, fail

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
