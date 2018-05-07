`timescale 1ns / 1ps
/*
 * File         : Set_RW_128x64.v
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
module Set_RW_128x64 #(parameter PABITS=36) (
    input clock,
    input reset,
    // Indexing Signals
    input  [(PABITS-11):0] Tag,             // Bits [35:10] of the 36-bit physical address.
    input  [5:0]           Index,           // Bits [9:4] of the 32-bit virtual / 36-bit physical address.
    input  [1:0]           Offset,          // Bits [3:2] of the 32-bit virtual / 36-bit physical address.
    input  [5:0]           LineIndex,       // Fill and Writeback index.
    input  [1:0]           LineOffset,      // Bits [3:2] of 32-bit byte address during a fill.
    // Word Data (Processor)
    input  [31:0]          WordIn,          // Store data from processor.
    output [31:0]          WordOut,         // Load data for processor.
    output                 Hit,             // Cacheline was a hit (one-cycle delay).
    output                 Valid,           // Cacheline was valid (one-cycle delay).
    output                 Dirty,           // Cacheline was dirty (one-cycle delay).
    output [(PABITS-11):0] IndexTag,        // Tag at 'Index' used for writebacks (one-cycle delay).
    // Line Data (Memory)
    input  [31:0]          LineIn,          // One word of memory data to fill the cache. Occurs in groups of four.
    output [127:0]         LineOut,         // A cacheline of data to be written to memory.
    // Commands
    input  [3:0]           WriteWord,       // Writes a subset of a 32-bit word from the processor to the cache.
    input                  ValidateLine,    // Writes the tag entry and sets 'Valid' (no actual loading).
    input                  InvalidateLine,  // Clears 'Valid' bit of the cacheline.
    input                  FillLine,        // Pulse indicating the line word 'LineIn' at 'LineOffset' should be written.
    input                  StoreTag,        // Writes 'StoreTagData' to the index specified by 'Index'
    input  [(PABITS-9):0]  StoreTagData     // Data for StoreTag operation (PABITS-9:2->Tag, 1:0->Valid/Dirty)
    );

    /* Operational Description
     *
     * This is a single set (or bank) of an n-way set-associative cache.
     * It behaves like a direct-mapped cache and has some, but not all of the logic
     * of an independent cache. Rather, a controller module organizes and oversees
     * the operation of each of the sets that comprise the cache.
     *
     * The set has two memories: A single-port tag and flag memory, and a dual-port
     * data memory. The tag/flag memory is written by the controller as a direct
     * result of processor cache commands or as an indirect result of processor
     * reads and writes.
     *
     * The data memory has one port for processor word accesses and another port
     * for memory fills and drains. The memory-facing output port is the size of
     * the cacheline while the memory-facing input port is word-sized to allow
     * prioritized requested-word-first line fills.
     *
     * Command Descriptions:
     *   ReadWord (de facto command):
     *     Attempt to read the word addressed by {Tag,Index,Offset}. After one
     *     cycle 'WordOut', 'Hit', and 'Valid' will be output. This output data
     *     is undefined during any cycle in which any other command is issued
     *     (as described below) as well as the cycle following the issuance of
     *     these commands.
     *
     *   WriteWord:
     *     Write a subset of the word 'WordIn' addressed by {Tag,Index,Offset}
     *     to the cache. The subset is zero or more bytes of the word determined
     *     by WriteWord[3:0] (i.e. a byte-enable write signal).
     *     Sets the valid and dirty bits, so control logic must make sure
     *     the line is valid before using this command. The write will be visible
     *     after one clock cycle.
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
     *     Write the valid bit and tag from 'StoreTagData[22]' and 'StoreTagData[21:0]'
     *     (respectively) to the index specified by 'Index'.
     */

    // Tag & Flag RAM signals
    wire [5:0] TR_Index;
    wire [(PABITS-11):0] TR_Tag_Cmp;
    wire [(PABITS-11):0] TR_Tag_Set;
    wire TR_Write;
    wire TR_SetValid;
    wire TR_SetDirty;
    wire [(PABITS-11):0] TR_MatchTag;
    wire TR_MatchHit;
    wire TR_MatchValid;
    wire TR_MatchDirty;

    // Data RAM signals
    wire [3:0]   DR_WriteA;
    wire [7:0]   DR_AddrA;
    wire [31:0]  DR_DataInA;
    wire [31:0]  DR_DataOutA;
    wire [15:0]  DR_WriteB;
    wire [5:0]   DR_AddrB;
    wire [127:0] DR_DataInB;
    wire [127:0] DR_DataOutB;

    // Local signals
    reg  [15:0] fill_we;
    reg  [127:0] fill_din;
    wire write_word_any;
    wire tag_write;
    wire tag_valid;
    wire tag_dirty;

    // Top-level assignments
    assign WordOut  = DR_DataOutA;
    assign Hit      = TR_MatchHit;
    assign Valid    = TR_MatchValid;
    assign Dirty    = TR_MatchDirty;
    assign IndexTag = TR_MatchTag;
    // A Xilinx BRAM with different port widths behaves as little-endian, but we expect word 0 in [31:0].
    assign LineOut  = {DR_DataOutB[31:0], DR_DataOutB[63:32], DR_DataOutB[95:64], DR_DataOutB[127:96]};

    // Tag & Flag RAM assignments
    assign TR_Index    = Index;
    assign TR_Tag_Cmp  = Tag;
    assign TR_Tag_Set  = (StoreTag) ? StoreTagData[(PABITS-9):2] : Tag;
    assign TR_Write    = tag_write;
    assign TR_SetValid = tag_valid;
    assign TR_SetDirty = tag_dirty;

    // Data RAM assignments
    assign DR_WriteA  = WriteWord;
    assign DR_AddrA   = {Index, Offset};
    assign DR_DataInA = WordIn;
    assign DR_WriteB  = fill_we;
    assign DR_AddrB   = LineIndex;
    assign DR_DataInB = fill_din;

    // Local assignments
    assign write_word_any = (WriteWord != 4'b0000);
    assign tag_write = write_word_any | ValidateLine | InvalidateLine | StoreTag;
    assign tag_valid = (StoreTag) ? (StoreTagData[1:0] != 2'b00) : (ValidateLine | write_word_any);
    assign tag_dirty = (StoreTag) ? (StoreTagData[1:0] == 2'b11) : write_word_any;

    // 32-bit word addresses are little-endian compared to 128-bit cache addresses in Xilinx BRAM.
    always @(*) begin
        case (LineOffset)
            2'b00: begin fill_we <= {{12{1'b0}}, {4{FillLine}}};           fill_din <= {{96{1'bx}}, LineIn}; end
            2'b01: begin fill_we <= {{8{1'b0}}, {4{FillLine}}, {4{1'b0}}}; fill_din <= {{64{1'bx}}, LineIn, {32{1'bx}}}; end
            2'b10: begin fill_we <= {{4{1'b0}}, {4{FillLine}}, {8{1'b0}}}; fill_din <= {{32{1'bx}}, LineIn, {64{1'bx}}}; end
            2'b11: begin fill_we <= {{4{FillLine}}, {12{1'b0}}};           fill_din <= {LineIn, {96{1'bx}}}; end
        endcase
    end

    TagFlagRam_RW_64 #(
        .PABITS      (PABITS))
        TagFlagRam (
        .clock       (clock),           // input clock
        .reset       (reset),           // input reset
        .Index       (TR_Index),        // input [5 : 0] Index
        .Tag_Cmp     (TR_Tag_Cmp),      // input [25 : 0] Tag_Cmp
        .Tag_Set     (TR_Tag_Set),      // input [25 : 0] Tag_Set
        .Write       (TR_Write),        // input Write
        .Valid       (TR_SetValid),     // input Valid
        .Dirty       (TR_SetDirty),     // input Dirty
        .MatchTag    (TR_MatchTag),     // output [25 : 0] MatchTag
        .MatchHit    (TR_MatchHit),     // output MatchHit
        .MatchValid  (TR_MatchValid),   // output MatchValid
        .MatchDirty  (TR_MatchDirty)    // output MatchDirty
    );

    BRAM_32x256_128x64_TDP_BE DataRam (
        .clka   (clock),       // input clka
        .rsta   (reset),       // input rsta
        .wea    (DR_WriteA),   // input [3 : 0] wea
        .addra  (DR_AddrA),    // input [7 : 0] addra
        .dina   (DR_DataInA),  // input [31 : 0] dina
        .douta  (DR_DataOutA), // output [31 : 0] douta
        .clkb   (clock),       // input clkb
        .rstb   (reset),       // input rstb
        .web    (DR_WriteB),   // input [15 : 0] web
        .addrb  (DR_AddrB),    // input [5 : 0] addrb
        .dinb   (DR_DataInB),  // input [127 : 0] dinb
        .doutb  (DR_DataOutB)  // output [127 : 0] doutb
    );

endmodule

