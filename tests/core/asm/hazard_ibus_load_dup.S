# =============================================================================
# hazard_ibus_load_dup.S
#
# Directed: IBUS stall while a completed load is in EX/MEM and the next insn
# is frozen in ID/EX. If EX/MEM advances (stall_ex_mem=0) while stall_id_ex=1,
# the ID/EX insn can be duplicated into EX/MEM and executed twice.
#
# Expect before fix: x1 == 2 (addi ran twice) -> tohost 6 (fail).
# Expect after fix:  x1 == 1 -> tohost 1 (pass).
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000
  addi x11, x0, 0x55
  sw   x11, 0(x10)

  addi x1, x0, 0

  lw   x12, 0(x10)
  addi x1, x1, 1

  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0

  addi x2, x0, 1
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
