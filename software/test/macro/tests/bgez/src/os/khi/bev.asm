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
    j       exc_tlb_bev
    nop
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
    j       exc_general_bev
    nop
    .end exc_general_bev

    .section .exc_interrupt_bev, "wx"
    .global exc_interrupt_bev
    .ent    exc_interrupt_bev
exc_interrupt_bev:
    j       exc_interrupt_bev
    nop
    .end exc_interrupt_bev

