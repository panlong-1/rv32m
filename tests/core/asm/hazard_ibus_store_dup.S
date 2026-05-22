# =============================================================================
# hazard_ibus_store_dup.S — Bug2: IBUS stall + store in MEM + stall_id_ex hack
#
# Requires testbench plusargs (see hazard_ibus_store_dup.plusargs):
#   +stall_ibus_during_mem_write=<N>
#
# After SBUS store in MEM with IBUS not-ready, addi x1,x1,1 must run once total.
# Known failure before hazard_unit fix: insn in ID/EX duplicated (x1 ends as 3).
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000
  addi x11, x0, 0x55
  addi x1, x0, 0

  sw   x11, 0(x10)         # store in MEM during IBUS stall window
  addi x1, x1, 1           # may overlap IBUS stall while store is in MEM
  addi x0, x0, 0
  addi x0, x0, 0
  addi x0, x0, 0

  addi x1, x1, 1           # x1 must be 2 (not 3 if prior addi ran twice)
  addi x2, x0, 2
  bne  x1, x2, fail

  lw   x3, 0(x10)
  bne  x3, x11, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 4
  sw   x21, 0(x20)
1:
  jal  x0, 1b
