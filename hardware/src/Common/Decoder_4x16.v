`timescale 1ns / 1ps
/*
 * File         : Decoder_4x16.v
 * Project      : MIPS32 MUX
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A simple 4-to-16 line single bit decoder. Accepts a four bit number
 *   and sets one of sixteen outputs high based on that number.
 *
 *   Mapping:
 *     0000  ->  0000_0000_0000_0001
 *     0001  ->  0000_0000_0000_0010
 *     0010  ->  0000_0000_0000_0100
 *     0011  ->  0000_0000_0000_1000
 *     ...
 */
module Decoder_4x16(
    input      [3:0]  A,
    output reg [15:0] B
    );

    always @(A) begin
        case (A)
            4'h0 : B <= 16'b0000_0000_0000_0001;
            4'h1 : B <= 16'b0000_0000_0000_0010;
            4'h2 : B <= 16'b0000_0000_0000_0100;
            4'h3 : B <= 16'b0000_0000_0000_1000;
            4'h4 : B <= 16'b0000_0000_0001_0000;
            4'h5 : B <= 16'b0000_0000_0010_0000;
            4'h6 : B <= 16'b0000_0000_0100_0000;
            4'h7 : B <= 16'b0000_0000_1000_0000;
            4'h8 : B <= 16'b0000_0001_0000_0000;
            4'h9 : B <= 16'b0000_0010_0000_0000;
            4'ha : B <= 16'b0000_0100_0000_0000;
            4'hb : B <= 16'b0000_1000_0000_0000;
            4'hc : B <= 16'b0001_0000_0000_0000;
            4'hd : B <= 16'b0010_0000_0000_0000;
            4'he : B <= 16'b0100_0000_0000_0000;
            4'hf : B <= 16'b1000_0000_0000_0000;
        endcase
    end

endmodule

