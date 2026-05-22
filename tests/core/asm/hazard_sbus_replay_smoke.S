# =============================================================================
# hazard_sbus_replay_smoke.S — one SBUS store to TORV UART THR @ 0x4000_1000
#
# Unfixed CPU replays the store while EX/MEM is held (ibus_stall / div in
# stall_front only); TB checks +replay_expect=1. Fixed CPU: exactly one THR push.
# Requires: hazard_sbus_replay_smoke.plusargs
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000
  lui  x9, 0x1
  add  x10, x10, x9
  addi x11, x0, 0x55
  addi x1, x0, 0

  sw   x11, 0(x10)
  addi x1, x1, 1

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
