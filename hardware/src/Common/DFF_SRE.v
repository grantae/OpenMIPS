`timescale 1ns / 1ps
/*
 * File         : DFF_SRE.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A variable-width register (d flip-flop) with configurable initial
 *   value, synchronous reset, and enable.
 */
module DFF_SRE #(parameter WIDTH=32, INIT={WIDTH{1'b0}})(
    input  clock,
    input  reset,
    input  enable,
    input  [(WIDTH-1):0] D,
    output reg [(WIDTH-1):0] Q
    );

    initial begin
        Q <= INIT;
    end

    always @(posedge clock) begin
        if (reset) begin
            Q <= INIT;
        end
        else if (enable) begin
            Q <= D;
        end
    end

endmodule

