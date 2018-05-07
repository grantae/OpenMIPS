###############################################################################
# File         : jumpchain.asm
# Project      : MIPS32 MUX
# Author:      : Grant Ayers (ayers@cs.stanford.edu)
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of jumping a lot
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
    ori     $v1, $0, 0
    j       $j1
    nop
    ori     $v1, 1
$j2:
    j       $j3
    nop
    ori     $v1, 1
$j1:
    j       $j2
    nop
    ori     $v1, 1
$j4:
    j       $j5
    nop
    ori     $v1, 1
$j5:
    sltiu   $v0, $v1, 1
    j       $end
    nop
$j3:
    j       $j4
    nop
    ori     $v1, 1
$end:


    #### Test code end ####

    bgtz    $s0, $begin
    addiu   $s0, $s0, -1

$done:
    lw      $s0, 0($sp)
    jr      $ra
    addiu   $sp, $sp, 4

    .end main
