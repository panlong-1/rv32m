OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  imem (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text*)
    *(.rodata*)
  } > imem
}
