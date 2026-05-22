# =============================================================================
# hazard_sbus_rx_replay_smoke.S — one UART RBR read must not replay on IBUS stall
#
# TB preloads RX byte (+uart_rx_byte). CPU issues one lw from 0x4000_1000 (RBR).
# Unfixed store-only dbus_completed: multiple RBR reads, FIFO drained.
# Fixed: replay guard on loads; +replay_expect_rbr=1.
# =============================================================================
  .section .text.init
  .globl _start

_start:
  lui  x10, 0x40000
  lui  x9, 0x1
  add  x10, x10, x9

  lw   x11, 0(x10)
  addi x7, x0, 0xAB
  bne  x11, x7, fail

pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

fail:
  lui  x20, 0xF0000
  addi x21, x0, 7
  sw   x21, 0(x20)
1:
  jal  x0, 1b
