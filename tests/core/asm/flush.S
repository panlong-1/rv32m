# =============================================================================
# flush.S — 控制流冲刷：始终 taken 分支、JAL 槽位无效指令、JALR 返回
# 期望：延迟槽/flush 后 x1 未被中间指令污染
# =============================================================================
  .section .text.init
  .globl _start

_start:
  addi x1, x0, 0
  beq  x0, x0, branch_taken
  addi x1, x0, 99
  jal  x0, fail

branch_taken:
  bne  x1, x0, fail
  jal  x0, jump_taken
  addi x1, x0, 88
  jal  x0, fail

jump_taken:
  bne  x1, x0, fail
  lui  x2, %hi(return_here)
  addi x2, x2, %lo(return_here)
  jalr x3, 0(x2)
  jal  x0, fail

return_here:
  bne  x1, x0, fail

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
