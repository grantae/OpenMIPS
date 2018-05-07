/* Linker script for MIPS32 (Single Core) using 256 KiB of memory */


/* Entry Point
 *
 * Set it to be the label "startup" (likely in startup.asm)
 *
 */
ENTRY(startup)


/* Memory Section
 *
 * Configuration for 256 KiB of memory:
 *
 * Instruction Memory starts at address 0.
 *
 * Data Memory ends 256 KiB later, at address 0x00040000 (the last
 * usable word address is 0x0003fffc).
 *
 *   Instructions :    0x00000000 -> 0x0001fffc    ( 128 KiB)
 *   Data / BSS   :    0x00020000 -> 0x00023ffc    (  16 KiB)
 *   Heap         :    0x00024000 -> 0x0002fffc    (  48 KiB)
 *   Stack        :    0x00030000 -> 0x0003fffc    (  64 KiB)
 */

SECTIONS
{
  . = 0 ;

  .text :
  {
    *(.startup)
    *(.*text*)
  }

  . = 0x00020000 ;

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

  . = ALIGN(4);
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

  . = 0x00024000 ;

  _heap_start = 0x0024000;
  _heap_end = 0x0030000;
  _sp = 0x00040000 ;
}
