`timescale 1ns / 1ps
/*
 * File         : Add.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A simple 2-input adder without carry.
 */
module Add #(parameter WIDTH=32) (
    input  [(WIDTH-1):0] A,
    input  [(WIDTH-1):0] B,
    output [(WIDTH-1):0] C
    );

    assign C = (A + B);

endmodule

