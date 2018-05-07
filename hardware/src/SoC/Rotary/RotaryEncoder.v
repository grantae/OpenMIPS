`timescale 1ns / 1ps
/*
 * File         : RotaryEncoder.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   3-Nov-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   MMIO module for a rotary encoder. 'Event' is intended
 *   as an interrupt and will remain high until a 'Read'
 *   command is issued. The output will be 0 if the rotation was
 *   leftward or 1 if the rotation was rightward.
 */
module RotaryEncoder(
    input clock,
    input reset,
    input Read,
    input Write,
    input [1:0] RotaryIn,
    output reg Ready,
    output reg Event,
    output reg EventRight
    );

    wire rotary_event;
    wire rotary_right;

    always @(posedge clock) begin
        Ready <= (Read | Write);
    end

    always @(posedge clock) begin
        Event <= (reset | Read) ? 1'b0 : ((rotary_event) ? 1'b1 : Event);
        EventRight <= (rotary_event) ? rotary_right : EventRight;
    end

    RotaryFilter RotaryFilter (
        .clock         (clock), 
        .rotary_in     (RotaryIn), 
        .rotary_event  (rotary_event), 
        .rotary_right  (rotary_right)
    );

endmodule
