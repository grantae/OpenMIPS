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
    j       exc_tlb
    nop
    .end exc_tlb

    .section .exc_cache, "wx"
    .global exc_cache
    .ent    exc_cache
exc_cache:
    j       exc_cache
    nop
    .end exc_cache

    .section .exc_general, "wx"
    .global exc_general
    .ent    exc_general
exc_general:
    mfc0    $k0, $13, 0     # Load cause register
    srl     $k0, $k0, 2
    andi    $k0, $k0, 0x1f
    addiu   $k0, $k0, -8    # Subtract Breakpoint ExcCode
    bne     $k0, $0, $skip
    nop
    ori     $v0, $0, 1      # Set the test to pass
$skip:
    mfc0    $k1, $14, 0     # EPC = EPC + 1 instruction
    addiu   $k1, $k1, 4
    mtc0    $k1, $14, 0
    eret
    .end exc_general

    .section .exc_interrupt, "wx"
    .global exc_interrupt
    .ent    exc_interrupt
exc_interrupt:
    j       exc_interrupt
    nop
    .end exc_interrupt

