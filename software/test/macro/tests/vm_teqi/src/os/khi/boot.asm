###############################################################################
# File         : boot.asm
# Project      : MIPS32 Release 1
# Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
# Date         : 1 June 2015
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Sets initial state of the processor on powerup.
#
###############################################################################

    .section .boot, "wx"
    .balign 4
    .global boot
    .ent    boot
    .set    noreorder
boot:
    # General setup
    mfc0    $k0, $12, 0         # Allow Cp0, no reverse-endian, no interrupts, user mode default, ~BEV
    lui     $k1, 0x1000
#    ori     $k1, 0x10           # 0x10 sets user mode (comment line for kernel mode)
    or      $k0, $k0, $k1
    lui     $k1, 0xfdbf
    ori     $k1, 0x00fe
    and     $k0, $k0, $k1
    mtc0    $k0, $12, 0
    lui     $k1, 0x0080         # Use the special interrupt vector
    mfc0    $k0, $13, 0
    or      $k0, $k0, $k1
    mtc0    $k0, $13, 0

    # Virtual memory
    ori     $k0, $0, 1          # Reserve (wire) 1 TLB entry for the system
    mtc0    $k0, $6, 0
    mtc0    $0, $0, 0           # Set the TLB index to 0
    lui     $k1, 0x0200         # Set the PFN to 2GB, cacheable, dirty, valid, global
    ori     $k1, 0x003f         #  for EntryLo0/EntryLo1.
    mtc0    $k1, $2, 0
    mtc0    $k1, $3, 0
    lui     $k0, 0x1            # Set the page size to 64KB (0xf) in the PageMask register
    ori     $k0, 0xe000
    mtc0    $k0, $5, 0
    ori     $k1, $0, 1
    mtc0    $k1, $10, 0         # Set VPN2 to map the first 64-KiB page. Set ASID to 1.
    tlbwi                       # Commit TLB entry 0 for the dual 64-KiB pages.

    # Return from reset exception
    la      $k0, $run           # Set the ErrorEPC address to $run
    mtc0    $k0, $30, 0
    eret

$run:
    ori     $k0, $0, 0x10       # Jump to virtual address 0x10 (user startup code)
    jalr    $k0
    nop

$write_result:
    lui     $t0, 0xbfff         # Load the special register base address 0xbffffff0
    ori     $t0, 0xfff0
    ori     $t1, $0, 1          # Set the done value
    sw      $v0, 8($t0)         # Set the return value from main() as the test result
    sw      $t1, 4($t0)         # Set 'done'

$done:
    j       $done               # Loop forever doing nothing
    nop

    .end boot
