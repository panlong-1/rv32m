# =============================================================================
# smoke.S — minimal smoke: ALU deps, MUL, arithmetic right shift, JAL/JALR, tohost
# PASS: sim log shows tohost PASS; FAIL: writes tohost=2 then spins
# =============================================================================
  .section .text.init
  .globl _start

_start:
  # ADDI chain exercises forwarding
  addi x1, x0, 5
  addi x2, x1, 3
  addi x3, x0, 8
  bne  x2, x3, fail

  addi x4, x0, 3
  addi x5, x0, 4
  mul  x6, x4, x5
  addi x7, x0, 12
  bne  x6, x7, fail

  # Arithmetic right shift (negative operand)
  addi x9, x0, -8
  srai x10, x9, 1
  addi x11, x0, -4
  bne  x10, x11, fail

  # JAL saves return address; callee uses x19, check after return
  jal  x1, subr
  addi x18, x0, 9
  bne  x19, x18, fail

# PASS: write 1 to tohost
pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

# FAIL: write 2 to tohost
fail:
  lui  x20, 0xF0000
  addi x21, x0, 2
  sw   x21, 0(x20)
1:
  jal  x0, 1b

subr:
  addi x19, x0, 9
  jalr x0, 0(x1)
