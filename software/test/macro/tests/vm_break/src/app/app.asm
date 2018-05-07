###############################################################################
# File         : app.asm
# Project      : MIPS32 MUX
# Author:      : Grant Ayers (ayers@cs.stanford.edu)
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'break' instruction.
#
###############################################################################


    .section .text
    .balign 4
    .set    noreorder
    .global main
    .ent    main
main:
    addiu   $sp, $sp, -4
    sw      $s0, 0($sp)
    ori     $s0, $0, 1          # Two iterations
$begin:

    #### Test code start ####

    break

    #### Test code end ####

    bgtz    $s0, $begin
    addiu   $s0, $s0, -1

$done:
    lw      $s0, 0($sp)
    jr      $ra
    addiu   $sp, $sp, 4

    .end main
