/* Linker script for MIPS32 (Single Core) */

/* Description:
 * Non-bootstrap exception vectors begin at virtual address 0x80000000
 * which maps to physical address 0x00000000. This region is called klow.
 */

/* Memory Section
 *
 * 16 KiB of memory is allowed for this section.
 *
 */

SECTIONS
{
  . = 0x80000000 ;

  .text :
  {
    *(.exc_tlb)

    . = 0x100 ;
    *(.exc_cache)

    . = 0x180 ;
    *(.exc_general)

    . = 0x200 ;
    *(.exc_interrupt)

    *(.*text*)
  }

  .data :
  {
    *(.rodata*)
    *(.data*)
  }

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

  .sbss :
  {
    *(.*sbss)
  }

  .bss :
  {
    *(.*bss)
  }

  . = 0x80004000 ;
}
