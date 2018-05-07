`timescale 1ns / 1ps
/*
 * File         : TagFlagRam_RO_256.v
 * Project      : XUM MIPS32 cache enhancement
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   3-Sep-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Cache tag and meta-data (valid, dirty, etc.) memory.
 */
module TagFlagRam_RO_256 #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    input  [7:0]           Index,      // Set index into tag memory
    input  [(PABITS-13):0] Tag_Cmp,    // Tag to compare to an index read (follows 'Index' by one cycle)
    input  [(PABITS-13):0] Tag_Set,    // Tag to write (enabled by 'Write')
    input                  Write,      // Enables the writing of 'Tag', 'Valid', and 'Dirty'
    input                  Valid,      // The value of the valid bit during a write
    output                 MatchHit,   // Tag hit (one-clock delay)
    output                 MatchValid  // Checked tag was valid (one-cycle delay)
    );

    wire [((PABITS-13)+1):0] dataIn = {Valid, Tag_Set};
    wire [((PABITS-13)+1):0] dataOut;

    assign MatchValid = dataOut[((PABITS-13)+1)];
    assign MatchHit   = MatchValid & (Tag_Cmp == dataOut[(PABITS-13):0]);

    RAM_SP_ZI #(
        .DATA_WIDTH (((PABITS-13)+1+1)),
        .ADDR_WIDTH (8))
        tag_flag_ram (
        .clk   (clock),     // input clk
        .rst   (reset),     // input rst
        .addr  (Index),     // input [7 : 0] addr
        .we    (Write),     // input we
        .din   (dataIn),    // input [36 : 0] din
        .dout  (dataOut)    // output [36 : 0] dout
    );

endmodule

