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

# 64 KiB pages
# Two 2x64 KiB (256 KiB) mapping: 0x0-0x3ffff virtual -> 0x80000000-0x8003ffff physical

    .section .boot, "wx"
    .balign 4
    .global boot
    .ent    boot
    .set    noreorder
boot:
    # First executed instruction at 0xbfc00000 (virt) / 0x1fc00000 (phys)
    #
    # General setup
    mfc0    $k0, $12, 0         # Allow Cp0, no RE, no BEV, interrupts on but masked, kernel mode
    lui     $k1, 0x1dbf
    ori     $k1, 0x00ee
    and     $k0, $k0, $k1
    lui     $k1, 0x1000
    ori     $k1, 0x1
    or      $k0, $k0, $k1
    mtc0    $k0, $12, 0
    lui     $k1, 0x0080         # Use the special interrupt vector (0x200 offset)
    mfc0    $k0, $13, 0
    or      $k0, $k0, $k1
    mtc0    $k0, $13, 0

    # Virtual memory: Map 256 KiB via 4x 64 KiB pages via 2 TLB entries
    # The translation is to set bit 31, e.g., 0x0 (virt) -> 0x80000000 (phys)
    ori     $k0, $0, 2          # Reserve (wire) 2 TLB entries
    mtc0    $k0, $6, 0
    lui     $k1, 0x0001         # Set the page size to 64 KiB (0xf)
    ori     $k1, 0xe000
    mtc0    $k1, $5, 0
    mtc0    $0, $0, 0           # Set the TLB index to 0
    lui     $k0, 0x0200         # Set PFN_0,0 to 0x80000000 + c/d/v/g
    ori     $k0, 0x003f
    mtc0    $k0, $2, 0
    ori     $k0, 0x0400         # Set PFN_0,1 to 0x80010000 + c/d/v/g
    mtc0    $k0, $3, 0
    ori     $k1, $0, 1          # Set VPN2_0 to 0x00000000 with ASID 1
    mtc0    $k1, $10, 0
    tlbwi                       # Commit the first two 64 KiB pages (total 128 KiB)
    ori     $k0, $0, 1          # Set the TLB index to 1
    mtc0    $k0, $0, 0
    lui     $k1, 0x0200         # Set PFN_1,0 to 0x80020000 + c/d/v/g
    ori     $k1, 0x083f
    mtc0    $k1, $2, 0
    ori     $k1, 0x0400         # Set PFN_1,1 to 0x80030000 + c/d/v/g
    mtc0    $k1, $3, 0
    lui     $k0, 0x0002         # Set VPN2_1 to 0x00020000 with ASID 1
    ori     $k0, 1
    mtc0    $k0, $10, 0
    tlbwi                       # Commit the second two 64 KiB pages (total 256 KiB)

    # Return from reset exception
    la      $k0, $run           # Set the ErrorEPC address to $run
    mtc0    $k0, $30, 0
    eret

$run:
    jalr    $0                  # Jump to virtual address 0x0 (user startup code)
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
