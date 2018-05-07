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
    addiu   $sp, -4             # Save some registers on the (user) stack
    sw      $ra, 0($sp)
    mfc0    $k0, $13, 0         # Load cause register
    srl     $k1, $k0, 2
    andi    $k1, 0x1f           # Save only ExcCode bits
    addiu   $k0, $0, 0x8        # 0x8 is Syscall
    bne     $k0, $k1, $spin_exc_general
    nop
    jal     syscall_handler
    nop
    mfc0    $k0, $13, 0         # Check Cause for BDS
    clo     $k1, $k0
    mfc0    $k0, $14, 0         # Adjust EPC: +0 (BDS) or +4 (no BDS)
    bne     $k1, $0, $end_exc_general
    nop
    addiu   $k0, 4
$end_exc_general:
    mtc0    $k0, $14, 0
    lw      $ra, 0($sp)
    addiu   $sp, 4
    eret
$spin_exc_general:
    j       $spin_exc_general
    nop
    .end exc_general

    .section .exc_interrupt, "wx"
    .global exc_interrupt
    .ent    exc_interrupt
exc_interrupt:
    # (0x80000200 / 0xa0000200, called as former)
    mfc0    $k0, $13, 0         # Cause
    mfc0    $k1, $12, 0         # Status
    andi    $k0, $k0, 0xff00    # Keep the IP bits
    and     $k0, $k0, $k1
    beq     $k0, $0, $int_end
    clz     $k0, $k0            # Find the 1st set bit (16..23)
    xori    $k0, 0x17           # 16..23 -> 7..0
    sll     $k0, 3
    la      $k1, $int_base
    addu    $k0, $k0, $k1
    jr      $k0
    nop
$int_base:
    j       $int_sw0
    nop
    j       $int_sw1
    nop
    j       $int_hw0
    nop
    j       $int_hw1
    nop
    j       $int_hw2
    nop
    j       $int_hw3
    nop
    j       $int_hw4
    nop
    j       $int_hw5
    nop
$int_sw0:
$int_sw1:
$int_hw0:
$int_hw1:
$int_hw2:
$int_hw3:
$int_hw4:
    j       $int_hw4
    nop
$int_hw5:
    la      $k0, timer_count    # Increment the 'bell' count
    lw      $k1, 0($k0)
    addiu   $k1, 1
    sw      $k1, 0($k0)
    la      $k0, timer_period   # Reset the interval
    lw      $k1, 0($k0)
    mfc0    $k0, $9, 0          # Count register
    addu    $k0, $k0, $k1
    mtc0    $k0, $11, 0         # Compare register
$int_end:
    eret
    .end exc_interrupt

    .section .text, "ax"
    .global syscall_handler
    .ent    syscall_handler
syscall_handler:
    # Register a0 contains the syscall:
    # 0->Mode, 1->Int
    beq     $a0, $0, $sys_mode
    addiu   $k0, $0, 1
    beq     $a0, $k0, $sys_int
    addiu   $k0, 1
    beq     $a0, $k0, $sys_timer
    addiu   $k0, 1
    beq     $a0, $k0, $sys_scratch
    nop
$spin_syscall_handler:
    j       $spin_syscall_handler
    nop
$sys_mode:
    move    $v0, $0             # Always returns 0
    # Register a1: 0->kernel, 1->user
    bne     $a1, $0, $sys_mode_user
    mfc0    $k0, $12, 0         # Status register
    lui     $k1, 0xffff
    ori     $k1, 0xffef
    and     $k0, $k0, $k1
    jr      $ra
    mtc0    $k0, $12, 0
$sys_mode_user:
    ori     $k0, 0x10
    jr      $ra
    mtc0    $k0, $12, 0
$sys_int:
    move    $v0, $0             # Always returns 0
    # Register a1: Interrupt mask [15:8], enable/disable [0]
    andi    $k0, $a1, 0x1
    andi    $k1, $a1, 0xff00
    beq     $k0, $0, $sys_int_disable
    mfc0    $k0, $12, 0         # Status register
    or      $k0, $k0, $k1
    jr      $ra
    mtc0    $k0, $12, 0
$sys_int_disable:
    nor     $k1, $k1, $k1
    and     $k0, $k0, $k1
    jr      $ra
    mtc0    $k0, $12, 0
$sys_timer:
    # Register a1: 0->TIMER_SET, 1->TIMER_GET_COUNT, 2->TIMER_GET_BELLS
    beq     $a1, $0, $sys_timer_set
    addiu   $k0, $0, 1
    beq     $a1, $k0, $sys_timer_count
    addiu   $k0, 1
    beq     $a1, $k0, $sys_timer_bells
    addiu   $v0, $0, 1          # Fail
    jr      $ra
    nop
$sys_timer_set:
    mfc0    $k0, $9, 0          # Count register
    addu    $k1, $k0, $a2
    mtc0    $k1, $11, 0         # Compare register
    la      $k0, timer_period
    sw      $a2, 0($k0)
    jr      $ra
    move    $v0, $0
$sys_timer_count:
    jr      $ra
    mfc0    $v0, $9, 0          # Count register
$sys_timer_bells:
    la      $k0, timer_count
    jr      $ra
    lw      $v0, 0($k0)
$sys_scratch:
    # Register a1: 0->SCRATCH_SET, 1->SCRATCH_GET
    lui     $k0, 0xbfff
    ori     $k0, 0xfffc
    beq     $a1, $0, $scratch_set
    addiu   $v0, $0, 1
    beq     $a1, $v0, $scratch_get
    nop
    jr      $ra
    nop
$scratch_set:
    jr      $ra
    sw      $a2, 0($k0)
$scratch_get:
    jr      $ra
    lw      $v0, 0($k0)
    .end    syscall_handler

    .section .data, "aw"
    .balign 16
    .global exc_data
timer_period:
    .word 0x00000000
timer_count:
    .word 0x00000000
