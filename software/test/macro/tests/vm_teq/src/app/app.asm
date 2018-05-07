###############################################################################
# File         : app.asm
# Project      : MIPS32 MUX
# Author:      : Grant Ayers (ayers@cs.stanford.edu)
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'teq' instruction.
#
###############################################################################


    .section .text
    .balign 4
    .set    noreorder
    .global main
    .ent    main
main:

    #### Test code start ####

    ori     $t0, $0, 0
    ori     $t1, $0, 5
    move    $v0, $0
    teq     $t0, $t1            # No trap
    bne     $v0, $0, $done
    move    $v0, $0
    teq     $t1, $t1            # Trap

    #### Test code end ####

$done:
    jr      $ra
    nop

    .end main
