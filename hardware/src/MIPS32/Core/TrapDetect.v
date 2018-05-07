`timescale 1ns / 1ps
/*
 * File         : TrapDetect.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Detects a Trap Exception in the pipeline.
 */
module TrapDetect(
    input  Trap,
    input  TrapCond,
    input  [31:0] ALUResult,
    output EXC_Tr
    );

    wire ALUZero = (ALUResult == 32'h00000000);
    assign EXC_Tr = Trap & (TrapCond ^ ALUZero);

endmodule

