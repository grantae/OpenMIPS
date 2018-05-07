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
#   A simple routine that returns 1 (success for the test infrastructure)
#
#   Replace this code with any basic test, but note that this routine runs in
#   kernel mode and does not initialize the processor, stack, or memory
#   sections in any way.
#
###############################################################################

    .section .startup, "wx"
    .balign 4
    .global startup
    .ent    startup
    .set    noreorder
startup:
    ori     $v0, $0, 1
    jr      $ra
    nop

    .end startup
