`timescale 1ns / 1ps                                                                                                                    
/*
 * File         : RotaryFilter.v
 * Project      : Unknown
 * Creator(s)   : Grant Ayers (ayers@cs.utah.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   16-Jul-2009  GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A simple rotary encoder filter that outputs rotary
 *   events and direction (left or right) which are free
 *   from mechanical bounce.
 */
module RotaryFilter(
    input clock,
    input [1:0] rotary_in,  // A:B
    output reg rotary_event,
    output reg rotary_right
    );

    reg q1;
    reg q2;
    reg delay_q1;

    always @(posedge clock) begin
        case (rotary_in)
            2'd0: begin q1 <= 1'b0; q2 <= q2;   end
            2'd1: begin q1 <= q1;   q2 <= 1'b0; end
            2'd2: begin q1 <= q1;   q2 <= 1'b1; end
            2'd3: begin q1 <= 1'b1; q2 <= q2;   end
        endcase
        delay_q1     <= q1;
        rotary_event <= q1 & ~delay_q1;
        rotary_right <= q2;
    end

endmodule

