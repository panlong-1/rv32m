# =============================================================================
# hazard_ibus_insn_dup.S — IBUS stall + frozen ID/EX must not duplicate into EX/MEM
#
# One SBUS store in MEM, then addi x1 while IBUS is not-ready (+plusargs).
# Unfixed hazard (EX/MEM advances while stall_id_ex): x1 ends as 3 (addi twice).
# Fixed: global stall_front + dbus_completed; x1 must be 2.
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000
  addi x11, x0, 0x55
  addi x1, x0, 0

  sw   x11, 0(x10)
  addi x1, x1, 1
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0

  addi x1, x1, 1
  addi x2, x0, 2
  bne  x1, x2, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 6
  sw   x21, 0(x20)
1:
  jal  x0, 1b
