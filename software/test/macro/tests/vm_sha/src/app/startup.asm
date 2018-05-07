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
    subu    $t2, $t1, $t0       # Number of bss bytes
    srl     $t2, 2              # Number of bss words

bss_clear_word:
    beq     $t2, $0, bss_clear_byte
    addiu   $t2, -1
    addiu   $t0, 4
    j       bss_clear_word
    sw      $0, -4($t0)

bss_clear_byte:
    beq     $t0, $t1, run
    addiu   $t0, 1
    j       bss_clear_byte
    sb      $0, -1($t0)

run:
    li      $a0, 0          # Switch to user mode via SYS_MODE
    li      $a1, 1
    syscall
    ori     $s0, $ra, 0     # Save the return address
    jal     main
    nop
    move    $t0, $v0        # Save the result before making a syscall
    move    $a0, $0         # Revert to kernel mode via SYS_MODE
    move    $a1, $0
    syscall
    ori     $ra, $s0, 0     # Restore the return address
    jr      $ra
    move    $v0, $t0

    .end startup
