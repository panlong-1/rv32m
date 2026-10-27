# =============================================================================
# sram_wbuf.S — IHP SRAM wrapper write buffer / read merge (torv_ahb_sram)
#
# Back-to-back accesses so a store's data phase meets a load's address phase:
# the store is parked in the write buffer and later loads must see it (full
# word and partial byte/halfword merges). Run on DBUS (0x2000_0000) and SBUS
# SRAM (0x4000_0000).
# =============================================================================
  .section .text.init
  .globl _start

# x3 = base. Uses x1, x2, x4-x9.
.macro WBUF_CHECKS
  # 1) sw A; lw B; lw A -> A is buffered, then read back through the buffer
  lui  x1, 0x11223
  addi x1, x1, 0x344
  sw   x1, 0(x3)
  lw   x2, 8(x3)
  lw   x4, 0(x3)
  bne  x4, x1, fail

  # 2) sb into a buffered word: A = 0x1122_AA44
  addi x5, x0, 0xAA
  sb   x5, 1(x3)
  lw   x2, 8(x3)
  lw   x4, 0(x3)
  lui  x6, 0x1122B
  addi x6, x6, -0x5BC          # 0x1122AA44
  bne  x4, x6, fail

  # 3) sh upper half while reads keep the port busy: A = 0xBEEF_AA44
  lui  x7, 0xBEEF0
  srli x7, x7, 16              # 0x0000_BEEF
  sh   x7, 2(x3)
  lw   x2, 8(x3)
  lw   x2, 12(x3)
  lw   x2, 8(x3)
  lw   x4, 0(x3)
  lui  x6, 0xBEEFB
  addi x6, x6, -0x5BC          # 0xBEEF_AA44
  bne  x4, x6, fail

  # 4) sw A; sw B; lw A; lw B -> A written directly, B buffered
  addi x8, x0, 0x123
  addi x9, x0, 0x456
  sw   x8, 16(x3)
  sw   x9, 20(x3)
  lw   x4, 16(x3)
  lw   x5, 20(x3)
  bne  x4, x8, fail
  bne  x5, x9, fail

  # 5) byte lanes of a buffered word, read back as bytes
  lb   x4, 0(x3)
  addi x5, x0, 0x44
  bne  x4, x5, fail
  lbu  x4, 3(x3)
  addi x5, x0, 0xBE
  bne  x4, x5, fail
.endm

_start:
  lui  x3, 0x20000
  WBUF_CHECKS
  lui  x3, 0x40000
  WBUF_CHECKS

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
