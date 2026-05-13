# Common bare-metal test termination macros.
#
# Testbenches watch RVTEST_TOHOST_ADDR and terminate immediately:
#   1        PASS
#   non-1    FAIL/error flag
#
# max_cycles in the simulator is only a watchdog for hung tests.

  .equ RVTEST_TOHOST_ADDR, 0xF0000000
  .equ RVTEST_PASS_FLAG,  1
  .equ RVTEST_FAIL_FLAG,  2

  .macro RVTEST_WRITE_TOHOST value:req, tmp_addr=x20, tmp_data=x21
    li \tmp_addr, RVTEST_TOHOST_ADDR
    li \tmp_data, \value
    sw \tmp_data, 0(\tmp_addr)
  .endm

  .macro RVTEST_PASS
    RVTEST_WRITE_TOHOST RVTEST_PASS_FLAG
  1:
    jal x0, 1b
  .endm

  .macro RVTEST_FAIL value=RVTEST_FAIL_FLAG
    RVTEST_WRITE_TOHOST \value
  1:
    jal x0, 1b
  .endm
