/* Linker script for MIPS32 (Single Core) */

/* Description:
 * MIPS begins execution at 0xbfc00000 which is a 4 MiB region (khigh) in kseg1
 * (unmapped and uncached) that maps to 0x1fc00000 in physical memory.
 *
 * This section contains startup code and bootstrap exception vectors for khigh.
 */

ENTRY(boot)

/* Memory Section
 *
 * 16 KiB of memory is allowed for the khigh section of kseg1.
 *
 */

SECTIONS
{
  . = 0xbfc00000 ;

  .text :
  {
    *(.boot)

    *(.test)

    . = 0x200 ;
    *(.exc_tlb_bev)

    . = 0x300 ;
    *(.exc_cache_bev)

    . = 0x380 ;
    *(.exc_general_bev)

    . = 0x400 ;
    *(.exc_interrupt_bev)

    . = 0x480 ;
    *(.exc_ejtag_trap)

    . = 0x500 ;
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
  . = 0xbfc03c00 ;  /* Space for 1 KiB output buffer (stdout) */

  . = 0xbfc04000 ;
}
