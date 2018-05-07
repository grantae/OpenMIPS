###############################################################################
# File         : startup.asm
# Project      : MIPS32 Release 1
# Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
# Date         : 1 February 2015
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   A simple routine that initializes the stack and BSS section and then
#   jumps to main. When main returns, jump back to the return address while
#   preserving the return value from main.
#
###############################################################################

    .section .startup, "wx"
    .balign 4
    .global startup
    .ent    startup
    .set    noreorder
startup:
    la      $t0, _bss_start     # Assumed aligned at 4-byte boundary
    la      $t1, _bss_end       # Any address after _bss_start
    la      $sp, _sp
    la      $gp, _gp
    beq     $t0, $t1, $run      # Skip bss initialization if no bss
    andi    $t2, $t1, 0xfffc
    beq     $t0, $t2, $bss_clear_byte
    nop

$bss_clear_word:
    addiu   $t0, 4
    bne     $t0, $t2, $bss_clear_word
    sw      $0, -4($t0)
    beq     $t0, $t1, $run
    nop

$bss_clear_byte:
    addiu   $t0, 1
    bne     $t0, $t1, $bss_clear_byte
    sb      $0, -1($t0)

$run:
    ori     $s0, $ra, 0     # Save the return address
    jal     main
    nop
    ori     $ra, $s0, 0     # Restore the return address
    jr      $ra
    nop

    .end startup
