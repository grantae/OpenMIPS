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
#   Exception vectors (non-bootstrap).
#
###############################################################################

    .balign 4
    .set    noreorder

    .section .exc_tlb, "wx"
    .global exc_tlb
    .ent    exc_tlb
exc_tlb:
    # (0x80000000 / 0xa0000000, called as former)
    j       exc_tlb
    nop
    .end exc_tlb

    .section .exc_cache, "wx"
    .global exc_cache
    .ent    exc_cache
exc_cache:
    # (0x80000100 / 0xa0000100, called as latter)
    j       exc_cache
    nop
    .end exc_cache

    .section .exc_general, "wx"
    .global exc_general
    .ent    exc_general
exc_general:
    # (0x80000180 / 0xa0000180, called as former)
    j       exc_general
    nop
    .end exc_general

    .section .exc_interrupt, "wx"
    .global exc_interrupt
    .ent    exc_interrupt
exc_interrupt:
    # (0x80000200 / 0xa0000200, called as former)
    j       exc_interrupt
    nop
    .end exc_interrupt

