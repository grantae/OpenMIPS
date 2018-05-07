`timescale 1ns / 1ps
/*
 * File         : Set_RO_128x256.v
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
 *   A single set (bank) of an n-way set-associative cache.
 *   Each set behaves as a direct-mapped cache and is controlled by
 *   an encapsulating cache module through a simple command interface.
 *   See in-source documentation below for more details.
 */
module Set_RO_128x256 #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    // Indexing Signals
    input  [(PABITS-13):0] Tag,            // Bits [35:12] of the 36-bit physical address.
    input  [7:0]           Index,          // Bits [11:4] of the 32-bit virtual / 36-bit physical address.
    input  [1:0]           Offset,         // Bits [3:2] of the 32-bit virtual / 36-bit physical address.
    input  [7:0]           LineIndex,      // Fill index.
    input  [1:0]           LineOffset,     // Bits [3:2] of an address during a fill.
    // Word Data (Processor)
    output [31:0]          WordOut,        // Load data for processor
    output                 Hit,            // Cacheline was a hit (one-cycle delay).
    output                 Valid,          // Cacheline was valid (one-cycle delay).
    // Line Data (Memory)
    input  [31:0]          LineIn,         // One word of memory data to fill the cache. Occurs in groups of four.
    // Commands
    input                  ValidateLine,   // Writes the tag entry and sets 'Valid' (no actual loading).
    input                  InvalidateLine, // Clears 'Valid' bit of the cacheline.
    input                  FillLine,       // Pulse indicating the line word 'LineIn' at 'LineOffset' should be written.
    input                  StoreTag,       // Writes 'StoreTagData' to the index specified by 'Index'
    input  [(PABITS-11):0] StoreTagData    // Data for StoreTag operation (PABITS-11:2->Tag, 1:0->Valid)
    );

    /* Operational Description
     *
     * This is a single set (or bank) of an n-way set-associative cache.
     * It behaves like a direct-mapped cache and has some, but not all of the logic
     * of an independent cache. Rather, a controller module organizes and oversees
     * the operation of each of the sets that comprise the cache.
     *
     * The set has two memories: A single-port tag and flag memory, and a read/write
     * data memory. The tag/flag memory is written by the controller as a direct
     * result of processor cache commands or as an indirect result of processor
     * reads and writes.
     *
     * The data memory has a read port for the processor and a write port for
     * cache line fills from memory. Both are 32-bits wide, thus cache fills
     * will write four words in sequence.
     *
     * Command Descriptions:
     *   ReadWord (de facto command):
     *     Attempt to read the word specified by {Tag,Index,Offset}. After one
     *     cycle 'WordOut', 'Hit', and 'Valid' will be output. This output data
     *     is undefined during any cycle in which any other command is issued
     *     (as described below) as well as the cycle following the issuance of
     *     these commands.
     *
     *   ValidateLine:
     *     Write the tag specified by 'Tag' to the index specified by 'Index' and
     *     set the valid bit.
     *
     *   InvalidateLine:
     *     Clear the valid bit of the cacheline specified by 'Tag' at index 'Index'.
     *
     *   FillLine:
     *     Write the 32-bit word 'LineIn' to the index specified by 'LineIndex' at
     *     the offset specified by 'LineOffset'.
     *
     *   StoreTag:
     *     Write the valid bit and tag from 'StoreTagData' to the index specified by 'Index'.
     */

    // Tag & Flag RAM signals
    wire [7:0]           TR_Index;
    wire [(PABITS-13):0] TR_Tag_Cmp;
    wire [(PABITS-13):0] TR_Tag_Set;
    wire                 TR_Write;
    wire                 TR_SetValid;
    wire                 TR_MatchHit;
    wire                 TR_MatchValid;

    // Data RAM signals
    wire        DR_Write;
    wire [9:0]  DR_AddrW;
    wire [31:0] DR_DataIn;
    wire [9:0]  DR_AddrR;
    wire [31:0] DR_DataOut;

    // Local signals
    wire tag_write;
    wire tag_valid;

    // Top-level assignments
    assign WordOut = DR_DataOut;
    assign Hit     = TR_MatchHit;
    assign Valid   = TR_MatchValid;

    // Tag & Flag RAM assignments
    assign TR_Index    = Index;
    assign TR_Tag_Cmp  = Tag;
    assign TR_Tag_Set  = (StoreTag) ? StoreTagData[(PABITS-11):2] : Tag;
    assign TR_Write    = tag_write;
    assign TR_SetValid = tag_valid;

    // Data RAM assignments
    assign DR_Write  = FillLine;
    assign DR_AddrW  = {LineIndex, LineOffset};
    assign DR_DataIn = LineIn;
    assign DR_AddrR  = {Index, Offset};

    // Local assignments
    assign tag_write = ValidateLine | InvalidateLine | StoreTag;
    assign tag_valid = (StoreTag) ? (StoreTagData[1:0] != 2'b00) : ValidateLine;

    TagFlagRam_RO_256 #(
        .PABITS      (PABITS))
        TagFlagRam (
        .clock       (clock),           // input clock
        .reset       (reset),           // input reset
        .Index       (TR_Index),        // input [7 : 0] Index
        .Tag_Cmp     (TR_Tag_Cmp),      // input [23 : 0] Tag_Cmp
        .Tag_Set     (TR_Tag_Set),      // input [23 : 0] Tag_Set
        .Write       (TR_Write),        // input Write
        .Valid       (TR_SetValid),     // input Valid
        .MatchHit    (TR_MatchHit),     // output MatchHit
        .MatchValid  (TR_MatchValid)    // output MatchValid
    );

    BRAM_32x1024_SDP DataRam (
        .clka   (clock),     // input clka
        .wea    (DR_Write),  // input wea
        .addra  (DR_AddrW),  // input [9 : 0] addra
        .dina   (DR_DataIn), // input [31 : 0] dina
        .clkb   (clock),     // input clkb
        .rstb   (reset),     // input rstb
        .addrb  (DR_AddrR),  // input [9 : 0] addrb
        .doutb  (DR_DataOut) // output [31 : 0] doutb
    );

endmodule

