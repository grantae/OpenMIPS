`timescale 1ns / 1ps
/*
 * File         : EvenOddPage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   20-Nov-2014  GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   TODO
 */
module EvenOddPage(
    input  [8:0]  VPN2_Slice,
    input  [15:0] Mask,
    output reg OddPage
    );

    always @(VPN2_Slice, Mask) begin
        casex (Mask)
            16'b0000_0000_0000_0000: OddPage <= VPN2_Slice[0]; // bit 12; 4KB page
            16'b0000_0000_0000_001x: OddPage <= VPN2_Slice[1]; // bit 14; 16KB page
            16'b0000_0000_0000_1xxx: OddPage <= VPN2_Slice[2]; // bit 16; 64KB page
            16'b0000_0000_001x_xxxx: OddPage <= VPN2_Slice[3]; // bit 18; 256KB page
            16'b0000_0000_1xxx_xxxx: OddPage <= VPN2_Slice[4]; // bit 20; 1MB page
            16'b0000_001x_xxxx_xxxx: OddPage <= VPN2_Slice[5]; // bit 22; 4MB page
            16'b0000_1xxx_xxxx_xxxx: OddPage <= VPN2_Slice[6]; // bit 24; 16MB page
            16'b001x_xxxx_xxxx_xxxx: OddPage <= VPN2_Slice[7]; // bit 26; 64MB page
            16'b1xxx_xxxx_xxxx_xxxx: OddPage <= VPN2_Slice[8]; // bit 28; 256MB page
            default: OddPage <= 1'b0;   // XXX revert to x
        endcase
    end

endmodule
