# =============================================================================
# hazard_branch_mem_stall.S — Bug1: taken branch in EX while MEM store stalls SBUS
#
# Requires testbench plusargs (see hazard_branch_mem_stall.plusargs):
#   +stall_sbus_writes=<N>  holds sbus_ready low on first SBUS store
#
# Expect: fall-through insn must not run; store completes; PC reaches target.
# Known failure before hazard_unit fix: flush during stall_mem loses branch.
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000        # SBUS data region
  addi x11, x0, 0xA5       # store pattern
  addi x12, x0, 0          # fall-through sentinel (must stay 0)

  sw   x11, 0(x10)         # MEM: SBUS store (TB stretches ready)
  beq  x0, x0, target      # EX: always-taken branch overlaps store stall
  addi x12, x0, 1          # must not execute if branch is honored
  jal  x0, fail

target:
  lw   x13, 0(x10)
  bne  x13, x11, fail
  bne  x12, x0, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 3
  sw   x21, 0(x20)
1:
  jal  x0, 1b
