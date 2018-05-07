###############################################################################
# File         : interrupt_timer.asm
# Project      : MIPS32 MUX
# Author:      : Grant Ayers (ayers@cs.stanford.edu)
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the timer interrupt, i.e., hardware interrupt 5
#
###############################################################################


    .section .test, "x"
    .balign 4
    .set    noreorder
    .global test
    .ent    test
test:
    lui     $s0, 0xbfff         # Load the base address 0xbffffff0
    ori     $s0, 0xfff0
    ori     $s1, $0, 1          # Prepare the 'done' status

    #### Test code start ####
    j       $setup              # Enable interrupts and exit boot mode
    nop

$run:
    j       $run                # The interrupt handler will terminate
    nop

$setup:
    mfc0    $k0, $9, 0          # Load the Count register
    addiu   $k0, 400            # Set Compare to the near future
    mtc0    $k0, $11, 0
    mfc0    $k0, $12, 0         # Load the Status register
    lui     $k1, 0x1000         # Allow access to CP0
    ori     $k1, 0x8001         # Enable timer int (hw int 5)
    or      $k0, $k0, $k1
    lui     $k1, 0x1dbf         # Disable CP3-1, No RE, No BEV
    ori     $k1, 0x80e7         # Only hw int 5, kernel mode, IE
    and     $k0, $k0, $k1
    mtc0    $k0, $12, 0         # Commit the new Status register
    mfc0    $k0, $13, 0         # Set Cause to the interrupt vector offset
    lui     $k1, 0x0080
    or      $k0, $k0, $k1
    mtc0    $k0, $13, 0
    la      $k0, $run           # Set ErrorEPC address to main test body
    mtc0    $k0, $30, 0
    eret

    #### Test code end ####

    .end test
