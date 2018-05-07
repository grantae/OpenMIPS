###############################################################################
# File         : bev.asm
# Project      : MIPS32 Release 1
# Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
# Date         : 24 January 2017
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
    mfc0    $k0, $13, 0                 # Read Cause for ExcCode
    srl     $k0, $k0, 2                 # Extract the ExcCode field
    andi    $k0, 0x001f
    beq     $k0, $0, exc_interrupt      # If interrupt, go there
    nop
    eret
    .end exc_general

    .section .exc_interrupt, "wx"
    .global exc_interrupt
    .ent    exc_interrupt
exc_interrupt:
    mfc0    $k0, $13, 0                 # Read Cause for IP bits
    mfc0    $k1, $12, 0                 # Read Status for IM bits
    andi    $k0, $k0, 0xff00            # Keep only IP bits
    and     $k0, $k0, $k1               # Mask pending with blocked (IM) bits
    beq     $k0, $0, $dismiss           # Spurious interrupt
    clz     $k0, $k0                    # Locate the first set bit: IP7..IP0 = 16..23
    xori    $k0, 0x17                   # 16..23 -> 7..0
    sll     $k0, $k0, 3                 # 8 bytes (2 instructions) per vector
    la      $k1, $vector_base
    addu    $k0, $k0, $k1
    jr      $k0
    nop
$dismiss:
    eret
$vector_base:
    j       interrupt_0
    nop
    j       interrupt_1
    nop
    j       interrupt_2
    nop
    j       interrupt_3
    nop
    j       interrupt_4
    nop
    j       interrupt_5
    nop
    j       interrupt_6
    nop
    j       interrupt_7
    nop

interrupt_0:
    eret
interrupt_1:
    eret
interrupt_2:
    eret
interrupt_3:
    eret
interrupt_4:
    eret
interrupt_5:
    eret
interrupt_6:
    eret
interrupt_7:    # AKA hardware int 5 (timer)
    lw      $k0, 0($a0)               # Increment the iteration counter
    addiu   $k0, 1
    sw      $k0, 0($a0)
    mfc0    $k1, $9, 0                # Set the timer for the near future
    addiu   $k1, 75
    andi    $k0, 0x7                  # (Add a bit of noise)
    addu    $k0, $k0, $k1
    mtc0    $k0, $11, 0
    eret

    .end exc_interrupt

