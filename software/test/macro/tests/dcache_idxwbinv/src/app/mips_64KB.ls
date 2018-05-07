/* Linker script for MIPS32 (Single Core) using 64 KiB of memory */


/* Entry Point
 *
 * Set it to be the label "startup" (likely in startup.asm)
 *
 */
ENTRY(startup)


/* Memory Section
 *
 * Configuration for 64 KiB of memory:
 *
 * Instruction Memory starts at address 0.
 *
 * Data Memory ends 64 KiB later, at address 0x00010000 (the last
 * usable word address is 0x0000fffc).
 *
 *   Instructions :    0x00000000 -> 0x00007fff    ( 32 KiB)
 *   Data / BSS   :    0x00008000 -> 0x0000afff    ( 12 KiB)
 *   Stack / Heap :    0x0000b000 -> 0x0000fffc    ( 20 KiB)
 */

SECTIONS
{
  _sp = 0x00010000;

  . = 0 ;

  .text :
  {
    *(.vectors)
    . = 0x10 ;
    *(.startup)
    *(.*text*)
  }

  . = 0x00008000 ;

  .data :
  {
    *(.rodata*)
    *(.data*)
  }

  . = ALIGN(1024);
  _gp = .;

  .got :
  {
    *(.got)
  }

  .sdata :
  {
    *(.*sdata*)
  }

  .MIPS.abiflags :
  {
    *(.MIPS.abiflags)
  }

  _bss_start = . ;

  .sbss :
  {
    *(.*sbss)
  }

  .bss :
  {
    *(.*bss)
  }

  _bss_end = . ;

  . = 0x0000b000 ;
}
