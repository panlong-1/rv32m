# =============================================================================
# smoke.S — 最小冒烟：ALU 依赖、MUL、算术右移、JAL/JALR 与 tohost
# 通过条件：仿真 log 含 [PASS] tohost；失败写 tohost=2 后自旋
# =============================================================================
  .section .text.init
  .globl _start

_start:
  # ADDI 链依赖前递
  addi x1, x0, 5
  addi x2, x1, 3
  addi x3, x0, 8
  bne  x2, x3, fail

  addi x4, x0, 3
  addi x5, x0, 4
  mul  x6, x4, x5
  addi x7, x0, 12
  bne  x6, x7, fail

  # 算术右移（负数）
  addi x9, x0, -8
  srai x10, x9, 1
  addi x11, x0, -4
  bne  x10, x11, fail

  # JAL 保存返回地址；子程序用 x19，返回后比对
  jal  x1, subr
  addi x18, x0, 9
  bne  x19, x18, fail

# PASS：tohost 写 1
pass:
  lui  x20, 0xF0000
  addi x21, x0, 1
  sw   x21, 0(x20)
1:
  jal  x0, 1b

# FAIL：tohost 写 2
fail:
  lui  x20, 0xF0000
  addi x21, x0, 2
  sw   x21, 0(x20)
1:
  jal  x0, 1b

subr:
  addi x19, x0, 9
  jalr x0, 0(x1)
