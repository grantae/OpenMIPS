###############################################################################
# File         : bev.asm
# Project      : MIPS32 Release 1
# Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
# Date         : 1 June 2015
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Bootstrap exception vectors.
#
###############################################################################

    .balign 4
    .set    noreorder

    .section .exc_tlb_bev, "wx"
    .global exc_tlb_bev
    .ent    exc_tlb_bev
exc_tlb_bev:
    # Make sure EPC is the instruction we expect (stored in $a0)
    mfc0    $k0, $14, 0
    subu    $k1, $a0, $k0
    sltiu   $v0, $k1, 1
    move    $k0, $ra         # Manually set the return address (stored in $ra)
    mtc0    $k0, $14, 0
    eret
    .end exc_tlb_bev


    .section .exc_cache_bev, "wx"
    .global exc_cache_bev
    .ent    exc_cache_bev
exc_cache_bev:
    j       exc_cache_bev
    nop
    .end exc_cache_bev

    .section .exc_general_bev, "wx"
    .global exc_general_bev
    .ent    exc_general_bev
exc_general_bev:
    # TLBL could have landed here if the address was present in the TLB, but invalid
    mfc0    $k0, $13, 0     # Load Cause to see if it's TLBL (0x2)
    srl     $k0, $k0, 2
    andi    $k0, $k0, 0x1f
    addiu   $k1, $k0, -2
    sltiu   $k0, $k1, 1     # 1 IIF cause was TLBL
    bne     $k0, $0, exc_tlb_bev
    nop
    mfc0    $k0, $14, 0
    addiu   $k0, 4
    mtc0    $k0, $14, 0
    eret
    .end exc_general_bev

    .section .exc_interrupt_bev, "wx"
    .global exc_interrupt_bev
    .ent    exc_interrupt_bev
exc_interrupt_bev:
    j       exc_interrupt_bev
    nop
    .end exc_interrupt_bev

