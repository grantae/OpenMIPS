`timescale 1ns / 1ps
/*
 * File         : TagFlagRam_RW_64.v
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
module TagFlagRam_RW_64 #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    input  [5:0]           Index,       // Set index into tag memory
    input  [(PABITS-11):0] Tag_Cmp,     // Tag to compare to an index read (follows 'Index' by one cycle)
    input  [(PABITS-11):0] Tag_Set,     // Tag to write (enabled by 'Write')
    input                  Write,       // Enables the writing of 'Tag', 'Valid', and 'Dirty'
    input                  Valid,       // The value of the valid bit during a write
    input                  Dirty,       // The value of the dirty bit during a write
    output [(PABITS-11):0] MatchTag,    // The tag of the given index (used for writebacks)
    output                 MatchHit,    // Tag hit (one-clock delay)
    output                 MatchValid,  // Checked tag was valid (one-cycle delay)
    output                 MatchDirty   // Checked tag was dirty (one-cycle delay)
    );

    wire [((PABITS-11)+2):0] dataIn = {Valid, Dirty, Tag_Set};
    wire [((PABITS-11)+2):0] dataOut;

    assign MatchTag   = dataOut[(PABITS-11):0];
    assign MatchValid = dataOut[((PABITS-11)+2)];
    assign MatchDirty = dataOut[((PABITS-11)+1)];
    assign MatchHit   = MatchValid & (Tag_Cmp == MatchTag);

    RAM_SP_ZI #(
        .DATA_WIDTH (((PABITS-11)+2+1)),
        .ADDR_WIDTH (6))
        tag_flag_ram (
        .clk   (clock),     // input clk
        .rst   (reset),     // input rst
        .addr  (Index),     // input [5 : 0] addr
        .we    (Write),     // input we
        .din   (dataIn),    // input [37 : 0] din
        .dout  (dataOut)    // output [37 : 0] dout
    );

endmodule

