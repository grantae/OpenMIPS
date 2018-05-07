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
    lui     $t0, 0xbfff         # Load the base address 0xbffffff0
    ori     $t0, 0xfff0
    ori     $t1, $0, 1          # Set the test result / done value
    sw      $t1, 8($t0)         # Set the test result
    sw      $t1, 4($t0)         # Set 'done'

$done:
    j       $done               # Loop forever doing nothing
    nop

    .end boot
