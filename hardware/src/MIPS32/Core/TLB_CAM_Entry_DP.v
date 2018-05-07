`timescale 1ns / 1ps
/*
 * File         : TLB_CAM_Entry_DP.v
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
 *   A dual-port Content-Addressable Memory (CAM) entry for MIPS32r1.
 */
module TLB_CAM_Entry_DP(
    input  clock,
    // Read/Write data
    input  [43:0] Data_In,  // {VPN2(19), Mask(16), ASID(8), G(1)}
    output [43:0] Data_Out, // {VPN2(19), Mask(16), ASID(8), G(1)}
    input         Write,
    // Match port A
    input  [19:0] VPN_A,
    input  [7:0]  ASID_A,
    output        Match_A,
    output        OddPage_A,
    // Match port B
    input  [19:0] VPN_B,
    input  [7:0]  ASID_B,
    output        Match_B,
    output        OddPage_B
    );

    // Mask the VPN for large pages
    wire [43:0] write_data = {Data_In[43:41], (Data_In[40:25] & ~Data_In[24:9]), Data_In[24:0]};

    // Other local signals
    wire [43:0] entry;
    wire [18:0] entry_vpn2   = entry[43:25];
    wire [15:0] entry_mask   = entry[24:9];
    wire [7:0]  entry_asid   = entry[8:1];
    wire        entry_g      = entry[0];
    wire        VPN2_Match_A = ({VPN_A[19:17], (VPN_A[16:1] & ~entry_mask[15:0])} == entry_vpn2);
    wire        ASID_Match_A = (ASID_A == entry_asid) | entry_g;
    wire [8:0]  VPN2_Slice_A = {VPN_A[16], VPN_A[14], VPN_A[12], VPN_A[10], VPN_A[8], VPN_A[6], VPN_A[4], VPN_A[2], VPN_A[0]};
    wire        VPN2_Match_B = ({VPN_B[19:17], (VPN_B[16:1] & ~entry_mask[15:0])} == entry_vpn2);
    wire        ASID_Match_B = (ASID_B == entry_asid) | entry_g;
    wire [8:0]  VPN2_Slice_B = {VPN_B[16], VPN_B[14], VPN_B[12], VPN_B[10], VPN_B[8], VPN_B[6], VPN_B[4], VPN_B[2], VPN_B[0]};
    wire        odd_a;
    wire        odd_b;

    // Top-level assignments
    assign Data_Out  = entry;
    assign Match_A   = VPN2_Match_A & ASID_Match_A;
    assign OddPage_A = odd_a;
    assign Match_B   = VPN2_Match_B & ASID_Match_B;
    assign OddPage_B = odd_b;

    // Entry: {Idx_VPN2[43:25], Idx_Mask[24:9], Idx_ASID[8:1], IDX_G[0]};
    DFF_E #(.WIDTH(44)) Entry (.clock(clock), .enable(Write), .D(write_data), .Q(entry));

    EvenOddPage EOP_A (
        .VPN2_Slice  (VPN2_Slice_A), // input [15 : 0] VPN2_Slice
        .Mask        (entry_mask),   // input [15 : 0] Mask
        .OddPage     (odd_a)         // output OddPage
    );

    EvenOddPage EOP_B (
        .VPN2_Slice  (VPN2_Slice_B), // input [15 : 0] VPN2_Slice
        .Mask        (entry_mask),   // input [15 : 0] Mask
        .OddPage     (odd_b)         // output OddPage
    );

endmodule

