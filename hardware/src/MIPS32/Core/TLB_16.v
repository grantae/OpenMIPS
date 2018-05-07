`timescale 1ns / 1ps
/*
 * File         : TLB_16.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   1-Nov-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A 16-entry TLB for MIPS32r1.
 *   Provides one port for instruction memory and one
 *   port for data memory. All TLB lookups are available
 *   after one clock edge.
 */
module TLB_16 #(parameter PABITS=36) (
    input  clock,
    input  reset,
    // Instruction Memory Port
    input  [19:0] VPN_I,             // Instruction memory VPN
    input  [7:0]  ASID_I,            // Instruction memory ASID
    output        Hit_I,             // Instruction memory page hit
    output [(PABITS-13):0] PFN_I,    // Instruction memory physical page translation
    output [2:0]  Cache_I,           // Instruction memory physical page cache attributes
    output        Dirty_I,           // Instruction memory physical page dirty attribute
    output        Valid_I,           // Instruction memory physical page valid attribute
    input         Stall_I,           // Instruction memory physical page stall attribute
    // Data Memory Port
    input  [19:0] VPN_D,             // Data memory or tlbp (EntryHi) VPN
    input  [7:0]  ASID_D,            // Data memory or tlbp (EntryHi) ASID
    output        Hit_D,             // Data memory or tlbp (~Index[31]) page hit
    output [(PABITS-13):0] PFN_D,    // Data memory physical page translation
    output [2:0]  Cache_D,           // Data memory physical page cache attributes
    output        Dirty_D,           // Data memory physical page dirty attribute
    output        Valid_D,           // Data memory physical page valid attribute
    input         Stall_D,           // Processor data memory pipeline stage is stalled
    // Control Input
    input  [3:0]  Index_In,          // Index used for tlbr, tlbwi/tlbwr
    input  [18:0] VPN2_In,           // VPN2 written on tlbwi/tlbwr
    input  [15:0] Mask_In,           // Mask written on tlbwi/tlbwr
    input  [7:0]  ASID_In,           // ASID written on tlbwi/tlbwr
    input         G_In,              // Global bit written on tlbwi/tlbwr
    input  [(PABITS-13):0] PFN0_In,  // Even PFN written on tlbwi/tlbwr
    input  [2:0]  C0_In,             // Even Cache bits written on tlbwi/tlbwr
    input         D0_In,             // Even Dirty bit written on tlbwi/tlbwr
    input         V0_In,             // Even Valid bit written on tlbwi/tlbwr
    input  [(PABITS-13):0] PFN1_In,  // Odd PFN written on tlbwi/tlbwr
    input  [2:0]  C1_In,             // Odd Cache bits written on tlbwi/tlbwr
    input         D1_In,             // Odd Dirty bit written on tlbwi/tlbwr
    input         V1_In,             // Odd Valid bit written on tlbwi/tlbwr
    // Control Output
    output [3:0]  Index_Out,         // Index output for tlbp
    output [18:0] VPN2_Out,          // VPN2 output for tlbr (EntryHi)
    output [15:0] Mask_Out,          // Mask output for tlbr (PageMask)
    output [7:0]  ASID_Out,          // ASID output for tlbr (EntryHi)
    output        G_Out,             // Global output for tlbr (EntryLo{0,1})
    output [(PABITS-13):0] PFN0_Out, // Even physical address for tlbr (EntryLo0)
    output [2:0]  C0_Out,            // Even physical address cache attributes for tlbr (EntryLo0)
    output        D0_Out,            // Even physical address dirty attribute for tlbr (EntryLo0)
    output        V0_Out,            // Even physical address valid attribute for tlbr (EntryLo0)
    output [(PABITS-13):0] PFN1_Out, // Odd physical address for tlbr (EntryLo1)
    output [2:0]  C1_Out,            // Odd physical address cache attributes for tlbr (EntryLo1)
    output        D1_Out,            // Odd physical address dirty attribute for tlbr (EntryLo1)
    output        V1_Out,            // Odd physical address valid attribute for tlbr (EntryLo1)
    // Control Command
    input         Read,              // Tlbr instruction
    input         Write,             // Tlbwi/Tlbwr instruction
    // Segment information
    input         Useg_MC,           // useg (addresses [0:2GB)) is mapped and cached (else neither)
    input  [2:0]  Kseg0_C            // kseg0 (addresses [2GB:2.5GB)) cacheability attributes
    );

    // Local signals
    wire [(PABITS-13):0] PFN0_Mask;
    wire [(PABITS-13):0] PFN1_Mask;
    wire        hold_a;
    wire        hold_b;
    wire        using_hold_data_a;
    wire        using_hold_data_b;
    wire        r_cmd_read;
    wire        r_cmd_write;
    wire [3:0]  r_idx_index;
    wire [18:0] r_idx_vpn2;
    wire [15:0] r_idx_mask;
    wire [7:0]  r_idx_asid;
    wire        r_idx_g;
    wire [19:0] r_vpn_a;
    wire [19:0] r_vpn_b;
    wire        r_unmapped_a;
    wire        r_unmapped_b;
    wire        r_uncached_a;
    wire        r_uncached_b;
    wire [7:0]  r_asid_a;
    wire [7:0]  r_asid_b;
    wire [((2*(PABITS-12))+9):0] r_write_data;   // TLB translation data to be written: {PFN0[23:0],C0[2:0],D0,V0,PFN1[23:0],C1[2:0],D1,V1}
    wire [2:0]  r_kseg0c;
    wire        r_use_kseg0c_a;
    wire        r_use_kseg0c_b;
    wire        s_unmapped_a;
    wire        s_unmapped_b;
    wire        s_uncached_a;
    wire        s_uncached_b;
    wire [2:0]  s_kseg0c_a;
    wire [2:0]  s_kseg0c_b;
    wire        s_use_kseg0c_a;
    wire        s_use_kseg0c_b;
    wire        s_hit_a_e;
    wire        s_hit_b_e;
    wire        s_hit_a_d;
    wire        s_hit_b_d;
    wire        s_oddPage_a_e;
    wire        s_oddPage_b_e;
    wire [(PABITS-13):0] s_pfn_a_e;
    wire [(PABITS-13):0] s_pfn_b_e;
    wire [(PABITS-13):0] s_pfn_a_d;
    wire [(PABITS-13):0] s_pfn_b_d;
    wire [(PABITS-13):0] s_unmapped_pfn_a_e;  // 20-24 bits (for 32-36 PABITS)
    wire [(PABITS-13):0] s_unmapped_pfn_b_e;
    wire [(PABITS-13):0] s_unmapped_pfn_a_d;
    wire [(PABITS-13):0] s_unmapped_pfn_b_d;
    wire [2:0]  s_c_a_e;
    wire [2:0]  s_c_b_e;
    wire [2:0]  s_c_a_d;
    wire [2:0]  s_c_b_d;
    wire        s_d_a_e;
    wire        s_d_b_e;
    wire        s_d_a_d;
    wire        s_d_b_d;
    wire        s_v_a_e;
    wire        s_v_b_e;
    wire        s_v_a_d;
    wire        s_v_b_d;
    wire [3:0]  s_idx_out_e;
    wire [3:0]  s_idx_out_d;
    wire [18:0] s_vpn2_out_e;
    wire [18:0] s_vpn2_out_d;
    wire [15:0] s_mask_out_e;
    wire [15:0] s_mask_out_d;
    wire [7:0]  s_asid_out_e;
    wire [7:0]  s_asid_out_d;
    wire        s_g_out_e;
    wire        s_g_out_d;
    wire [(PABITS-13):0] s_pfn0_out_e;
    wire [(PABITS-13):0] s_pfn0_out_d;
    wire [2:0]  s_c0_out_e;
    wire [2:0]  s_c0_out_d;
    wire        s_d0_out_e;
    wire        s_d0_out_d;
    wire        s_v0_out_e;
    wire        s_v0_out_d;
    wire [(PABITS-13):0] s_pfn1_out_e;
    wire [(PABITS-13):0] s_pfn1_out_d;
    wire [2:0]  s_c1_out_e;
    wire [2:0]  s_c1_out_d;
    wire        s_d1_out_e;
    wire        s_d1_out_d;
    wire        s_v1_out_e;
    wire        s_v1_out_d;

    // Virtual large page signals
    generate
        if (PABITS < 28) begin: g
            wire [(PABITS-13):0] s_vlpn_a_e;
            wire [(PABITS-13):0] s_vlpn_b_e;
            reg  [(PABITS-13):0] s_vlpn_a_d;    // XXX possibly not needed
            reg  [(PABITS-13):0] s_vlpn_b_d;    // XXX possibly not needed
        end
        else begin: g
            wire [15:0] s_vlpn_a_e;
            wire [15:0] s_vlpn_b_e;
            reg  [15:0] s_vlpn_a_d; // XXX possibly not needed
            reg  [15:0] s_vlpn_b_d; // XXX possibly not needed
        end
    endgenerate

    // Unmapped translation
    generate
        if (PABITS < 32) begin
            reg  [(PABITS-13):0] s_unmapped_pfn_part_a;
            reg  [(PABITS-13):0] s_unmapped_pfn_part_b;
            wire [(PABITS-13):0] r_unmapped_pfn_part_a;
            wire [(PABITS-13):0] r_unmapped_pfn_part_b;
            assign s_unmapped_pfn_a_e = s_unmapped_pfn_part_a;
            assign s_unmapped_pfn_b_e = s_unmapped_pfn_part_b;
            always @(posedge clock) begin
                if (reset) begin
                    s_unmapped_pfn_part_a <= {(PABITS-12){1'b0}};
                    s_unmapped_pfn_part_b <= {(PABITS-12){1'b0}};
                end
                else begin
                    s_unmapped_pfn_part_a <= r_unmapped_pfn_part_a;
                    s_unmapped_pfn_part_b <= r_unmapped_pfn_part_b;
                end
            end
            if (PABITS < 30) begin
                assign r_unmapped_pfn_part_a = r_vpn_a[(PABITS-13):0];
                assign r_unmapped_pfn_part_b = r_vpn_b[(PABITS-13):0];
            end
            else if (PABITS < 31) begin
                assign r_unmapped_pfn_part_a = {(r_vpn_a[17] & ~r_vpn_a[19]), r_vpn_a[(PABITS-14):0]};
                assign r_unmapped_pfn_part_b = {(r_vpn_b[17] & ~r_vpn_b[19]), r_vpn_b[(PABITS-14):0]};
            end
            else begin
                assign r_unmapped_pfn_part_a = {(r_vpn_a[18] & ~r_vpn_a[19]), (r_vpn_a[17] & ~r_vpn_a[19]), r_vpn_a[(PABITS-15):0]};
                assign r_unmapped_pfn_part_b = {(r_vpn_b[18] & ~r_vpn_b[19]), (r_vpn_b[17] & ~r_vpn_b[19]), r_vpn_b[(PABITS-15):0]};
            end
        end
        else begin
            reg  [18:0] s_unmapped_pfn_part_a;
            reg  [18:0] s_unmapped_pfn_part_b;
            wire [18:0] r_unmapped_pfn_part_a = {(r_vpn_a[18] & ~r_vpn_a[19]), (r_vpn_a[17] & ~r_vpn_a[19]), r_vpn_a[16:0]};   // kuseg logic
            wire [18:0] r_unmapped_pfn_part_b = {(r_vpn_b[18] & ~r_vpn_b[19]), (r_vpn_b[17] & ~r_vpn_b[19]), r_vpn_b[16:0]};
            assign s_unmapped_pfn_a_e = {{(PABITS-31){1'b0}}, s_unmapped_pfn_part_a};
            assign s_unmapped_pfn_b_e = {{(PABITS-31){1'b0}}, s_unmapped_pfn_part_b};
            always @(posedge clock) begin
                if (reset) begin
                    s_unmapped_pfn_part_a <= {19{1'b0}};
                    s_unmapped_pfn_part_b <= {19{1'b0}};
                end
                else begin
                    s_unmapped_pfn_part_a <= r_unmapped_pfn_part_a;
                    s_unmapped_pfn_part_b <= r_unmapped_pfn_part_b;
                end
            end
        end
    endgenerate

    // Unmapped translation upper-bit padding
    generate
        if (PABITS < 31) begin
            DFF_E #(.WIDTH(PABITS-12)) S_Unmapped_PFN_A_D (.clock(clock), .enable(~using_hold_data_a), .D(s_unmapped_pfn_a_e), .Q(s_unmapped_pfn_a_d));
            DFF_E #(.WIDTH(PABITS-12)) S_Unmapped_PFN_B_D (.clock(clock), .enable(~using_hold_data_b), .D(s_unmapped_pfn_b_e), .Q(s_unmapped_pfn_b_d));
        end
        else begin
            wire [18:0] s_unmapped_pfn_part_a_d;
            wire [18:0] s_unmapped_pfn_part_b_d;
            DFF_E #(.WIDTH(19)) S_Unmapped_PFN_A_D (.clock(clock), .enable(~using_hold_data_a), .D(s_unmapped_pfn_a_e[18:0]), .Q(s_unmapped_pfn_part_a_d));
            DFF_E #(.WIDTH(19)) S_Unmapped_PFN_B_D (.clock(clock), .enable(~using_hold_data_b), .D(s_unmapped_pfn_b_e[18:0]), .Q(s_unmapped_pfn_part_b_d));
            assign s_unmapped_pfn_a_d = {{(PABITS-31){1'b0}}, s_unmapped_pfn_part_a_d};
            assign s_unmapped_pfn_b_d = {{(PABITS-31){1'b0}}, s_unmapped_pfn_part_b_d};
        end
    endgenerate

    // Content-Addressable Memory signals
    wire [3:0]  CAM_Idx_Index;
    wire        CAM_Idx_Write;
    wire [18:0] CAM_Idx_VPN2;
    wire [15:0] CAM_Idx_Mask;
    wire [7:0]  CAM_Idx_ASID;
    wire        CAM_Idx_G;
    wire [18:0] CAM_Idx_VPN2_Out;
    wire [15:0] CAM_Idx_Mask_Out;
    wire [7:0]  CAM_Idx_ASID_Out;
    wire        CAM_Idx_G_Out;
    wire [19:0] CAM_VPN_A,        CAM_VPN_B;
    wire [7:0]  CAM_ASID_A,       CAM_ASID_B;
    wire        CAM_Match_A,      CAM_Match_B;
    wire [3:0]  CAM_MatchIndex_A, CAM_MatchIndex_B;
    wire        CAM_OddPage_A,    CAM_OddPage_B;
    wire [15:0] CAM_Mask_A,       CAM_Mask_B;

    // Translation RAM signals
    wire [3:0]  RAM_addra, RAM_addrb;
    wire        RAM_wea,   RAM_web;
    wire [((2*(PABITS-12))+9):0] RAM_dina,  RAM_dinb;
    wire [((2*(PABITS-12))+9):0] RAM_douta, RAM_doutb;


    // **** Assignments **** //

    // Top-level assignments
    assign Hit_I     = (s_unmapped_b) ? 1'b1              : ((using_hold_data_b) ? s_hit_b_d : s_hit_b_e);
    assign PFN_I     = (s_unmapped_b) ? ((using_hold_data_b) ? s_unmapped_pfn_b_d : s_unmapped_pfn_b_e) : ((using_hold_data_b) ? s_pfn_b_d : s_pfn_b_e);
    assign Cache_I   = (s_uncached_b) ? 3'b010            : ((using_hold_data_b) ? s_c_b_d   : s_c_b_e);
    assign Dirty_I   = (s_unmapped_b) ? 1'b1              : ((using_hold_data_b) ? s_d_b_d   : s_d_b_e);
    assign Valid_I   = (s_unmapped_b) ? 1'b1              : ((using_hold_data_b) ? s_v_b_d   : s_v_b_e);
    assign Hit_D     = (s_unmapped_a) ? 1'b1              : ((using_hold_data_a) ? s_hit_a_d : s_hit_a_e);
    assign PFN_D     = (s_unmapped_a) ? ((using_hold_data_a) ? s_unmapped_pfn_a_d : s_unmapped_pfn_a_e) : ((using_hold_data_a) ? s_pfn_a_d : s_pfn_a_e);
    assign Cache_D   = (s_uncached_a) ? 3'b010            : ((using_hold_data_a) ? s_c_a_d   : s_c_a_e);
    assign Dirty_D   = (s_unmapped_a) ? 1'b1              : ((using_hold_data_a) ? s_d_a_d   : s_d_a_e);
    assign Valid_D   = (s_unmapped_a) ? 1'b1              : ((using_hold_data_a) ? s_v_a_d   : s_v_a_e);
    assign Index_Out = (using_hold_data_a) ? s_idx_out_d  : s_idx_out_e;
    assign VPN2_Out  = (using_hold_data_a) ? s_vpn2_out_d : s_vpn2_out_e;
    assign Mask_Out  = (using_hold_data_a) ? s_mask_out_d : s_mask_out_e;
    assign ASID_Out  = (using_hold_data_a) ? s_asid_out_d : s_asid_out_e;
    assign G_Out     = (using_hold_data_a) ? s_g_out_d    : s_g_out_e;
    assign PFN0_Out  = (using_hold_data_a) ? s_pfn0_out_d : s_pfn0_out_e;
    assign C0_Out    = (using_hold_data_a) ? s_c0_out_d   : s_c0_out_e;
    assign D0_Out    = (using_hold_data_a) ? s_d0_out_d   : s_d0_out_e;
    assign V0_Out    = (using_hold_data_a) ? s_v0_out_d   : s_v0_out_e;
    assign PFN1_Out  = (using_hold_data_a) ? s_pfn1_out_d : s_pfn1_out_e;
    assign C1_Out    = (using_hold_data_a) ? s_c1_out_d   : s_c1_out_e;
    assign D1_Out    = (using_hold_data_a) ? s_d1_out_d   : s_d1_out_e;
    assign V1_Out    = (using_hold_data_a) ? s_v1_out_d   : s_v1_out_e;

    // CAM assignments
    assign CAM_Idx_Index = r_idx_index;
    assign CAM_Idx_Write = r_cmd_write;
    assign CAM_Idx_VPN2  = r_idx_vpn2;
    assign CAM_Idx_Mask  = r_idx_mask;
    assign CAM_Idx_ASID  = r_idx_asid;
    assign CAM_Idx_G     = r_idx_g;
    assign CAM_VPN_A     = r_vpn_a;
    assign CAM_ASID_A    = r_asid_a;
    assign CAM_VPN_B     = r_vpn_b;
    assign CAM_ASID_B    = r_asid_b;

    // RAM assignments
    assign RAM_addra     = (r_cmd_read | r_cmd_write) ? r_idx_index : CAM_MatchIndex_A;
    assign RAM_wea       = r_cmd_write;
    assign RAM_dina      = r_write_data;
    assign RAM_addrb     = CAM_MatchIndex_B;
    assign RAM_web       = 1'b0;
    assign RAM_dinb      = {((2*(PABITS-12))+10){1'b0}};

    // Local assignments
    assign hold_a        = Stall_D;
    assign hold_b        = Stall_I;
    assign r_cmd_read    = Read;
    assign r_cmd_write   = Write;
    assign r_idx_index   = Index_In;
    assign r_idx_vpn2    = VPN2_In;
    assign r_idx_mask    = Mask_In;
    assign r_idx_asid    = ASID_In;
    assign r_idx_g       = G_In;
    assign r_vpn_a       = VPN_D;
    assign r_vpn_b       = VPN_I;
    assign r_unmapped_a  = (r_vpn_a[19:18] == 2'b10)  | ((r_vpn_a[19] == 1'b0) & ~Useg_MC);
    assign r_unmapped_b  = (r_vpn_b[19:18] == 2'b10)  | ((r_vpn_b[19] == 1'b0) & ~Useg_MC);
    assign r_uncached_a  = (r_vpn_a[19:17] == 3'b101) | ((r_vpn_a[19] == 1'b0) & ~Useg_MC);
    assign r_uncached_b  = (r_vpn_b[19:17] == 3'b101) | ((r_vpn_b[19] == 1'b0) & ~Useg_MC);
    assign r_asid_a      = ASID_D;
    assign r_asid_b      = ASID_I;
    assign r_write_data  = {PFN0_Mask, C0_In, D0_In, V0_In, PFN1_Mask, C1_In, D1_In, V1_In};
    assign r_kseg0c      = Kseg0_C;
    assign r_use_kseg0c_a = (r_vpn_a[19:17] == 3'b100);
    assign r_use_kseg0c_b = (r_vpn_b[19:17] == 3'b100);
    assign s_pfn_a_e     = g.s_vlpn_a_e | ((s_oddPage_a_e) ? RAM_douta[(PABITS-8):5] : RAM_douta[((2*(PABITS-12))+9):(PABITS-2)]);
    assign s_pfn_b_e     = g.s_vlpn_b_e | ((s_oddPage_b_e) ? RAM_doutb[(PABITS-8):5] : RAM_doutb[((2*(PABITS-12))+9):(PABITS-2)]);
    assign s_c_a_e       = (s_use_kseg0c_a) ? s_kseg0c_a : ((s_oddPage_a_e) ? RAM_douta[4:2]  : RAM_douta[(PABITS-3):(PABITS-5)]);
    assign s_c_b_e       = (s_use_kseg0c_b) ? s_kseg0c_b : ((s_oddPage_b_e) ? RAM_doutb[4:2]  : RAM_doutb[(PABITS-3):(PABITS-5)]);
    assign s_d_a_e       = (s_oddPage_a_e) ? RAM_douta[1]    : RAM_douta[(PABITS-6)];
    assign s_d_b_e       = (s_oddPage_b_e) ? RAM_doutb[1]    : RAM_doutb[(PABITS-6)];
    assign s_v_a_e       = (s_oddPage_a_e) ? RAM_douta[0]    : RAM_douta[(PABITS-7)];
    assign s_v_b_e       = (s_oddPage_b_e) ? RAM_doutb[0]    : RAM_doutb[(PABITS-7)];
    // {PFN0[23:0],C0[2:0],D0,V0,PFN1[23:0],C1[2:0],D1,V1}
    // 36-bit: {PFN0[57:34],C0[33:31],D0[30],V0[29],PFN1[28:5],C1[4:2],D1[1],V1[0]}
    //         {Idx_VPN2[43:25], Idx_Mask[24:9], Idx_ASID[8:1], IDX_G[0]};
    // 32-bit: {PFN0[49:30],C0[29:27],D0[26],V0[25],PFN1[24:5],C1[4:2],D1[1],V1[0]}
    assign s_idx_out_e   = CAM_MatchIndex_A;
    assign s_pfn0_out_e  = RAM_douta[((2*(PABITS-12))+9):(PABITS-2)];
    assign s_c0_out_e    = RAM_douta[(PABITS-3):(PABITS-5)];
    assign s_d0_out_e    = RAM_douta[(PABITS-6)];
    assign s_v0_out_e    = RAM_douta[(PABITS-7)];
    assign s_pfn1_out_e  = RAM_douta[(PABITS-8):5];
    assign s_c1_out_e    = RAM_douta[4:2];
    assign s_d1_out_e    = RAM_douta[1];
    assign s_v1_out_e    = RAM_douta[0];

    // Large page PFN masking
    generate
        if (PABITS < 28) begin
            assign PFN0_Mask = PFN0_In & ~Mask_In[(PABITS-13):0];
            assign PFN1_Mask = PFN1_In & ~Mask_In[(PABITS-13):0];
        end
        else if (PABITS == 28) begin
            assign PFN0_Mask = PFN0_In & ~Mask_In;
            assign PFN1_Mask = PFN1_In & ~Mask_In;
        end
        else begin
            assign PFN0_Mask = {PFN0_In[(PABITS-13):16], (PFN0_In[15:0] & ~Mask_In)};
            assign PFN1_Mask = {PFN1_In[(PABITS-13):16], (PFN1_In[15:0] & ~Mask_In)};
        end
    endgenerate

    // Large page offset bits
    generate
        if (PABITS < 28) begin
            wire [(PABITS-13):0] vlpn_a_in = VPN_D[(PABITS-13):0] & CAM_Mask_A[(PABITS-13):0];
            wire [(PABITS-13):0] vlpn_b_in = VPN_I[(PABITS-13):0] & CAM_Mask_B[(PABITS-13):0];
            DFF_E #(.WIDTH(PABITS-12)) S_VLPN_A_E (.clock(clock), .enable(1'b1), .D(vlpn_a_in), .Q(g.s_vlpn_a_e));
            DFF_E #(.WIDTH(PABITS-12)) S_VLPN_B_E (.clock(clock), .enable(1'b1), .D(vlpn_b_in), .Q(g.s_vlpn_b_e));
        end
        else begin
            wire [15:0] vlpn_a_in = VPN_D[15:0] & CAM_Mask_A;
            wire [15:0] vlpn_b_in = VPN_I[15:0] & CAM_Mask_B;
            DFF_E #(.WIDTH(16)) S_VLPN_A_E (.clock(clock), .enable(1'b1), .D(vlpn_a_in), .Q(g.s_vlpn_a_e));
            DFF_E #(.WIDTH(16)) S_VLPN_B_E (.clock(clock), .enable(1'b1), .D(vlpn_b_in), .Q(g.s_vlpn_b_e));
        end
    endgenerate

    // Hold data enable
    DFF_E #(.WIDTH(1)) Using_Hold_Data_A (.clock(clock), .enable(1'b1), .D(hold_a), .Q(using_hold_data_a));
    DFF_E #(.WIDTH(1)) Using_Hold_Data_B (.clock(clock), .enable(1'b1), .D(hold_b), .Q(using_hold_data_b));

    // Service stage pseudo-ephemeral data
    DFF_E #(.WIDTH(1))         S_Hit_A_E     (.clock(clock), .enable(1'b1), .D(CAM_Match_A),      .Q(s_hit_a_e));
    DFF_E #(.WIDTH(1))         S_Hit_B_E     (.clock(clock), .enable(1'b1), .D(CAM_Match_B),      .Q(s_hit_b_e));
    DFF_E #(.WIDTH(1))         S_OddPage_A_E (.clock(clock), .enable(1'b1), .D(CAM_OddPage_A),    .Q(s_oddPage_a_e));
    DFF_E #(.WIDTH(1))         S_OddPage_B_E (.clock(clock), .enable(1'b1), .D(CAM_OddPage_B),    .Q(s_oddPage_b_e));
    DFF_E #(.WIDTH(19))        S_VPN2_Out_E  (.clock(clock), .enable(1'b1), .D(CAM_Idx_VPN2_Out), .Q(s_vpn2_out_e));
    DFF_E #(.WIDTH(16))        S_Mask_Out_E  (.clock(clock), .enable(1'b1), .D(CAM_Idx_Mask_Out), .Q(s_mask_out_e));
    DFF_E #(.WIDTH(8))         S_ASID_Out_E  (.clock(clock), .enable(1'b1), .D(CAM_Idx_ASID_Out), .Q(s_asid_out_e));
    DFF_E #(.WIDTH(1))         S_G_Out_E     (.clock(clock), .enable(1'b1), .D(CAM_Idx_G_Out),    .Q(s_g_out_e));

    // Service stage and delay/stall data
    DFF_E #(.WIDTH(1))         S_Unmapped_A       (.clock(clock), .enable(~hold_a),            .D(r_unmapped_a),       .Q(s_unmapped_a));
    DFF_E #(.WIDTH(1))         S_Unmapped_B       (.clock(clock), .enable(~hold_b),            .D(r_unmapped_b),       .Q(s_unmapped_b));
    DFF_E #(.WIDTH(1))         S_Uncached_A       (.clock(clock), .enable(~hold_a),            .D(r_uncached_a),       .Q(s_uncached_a));
    DFF_E #(.WIDTH(1))         S_Uncached_B       (.clock(clock), .enable(~hold_b),            .D(r_uncached_b),       .Q(s_uncached_b));
    DFF_E #(.WIDTH(3))         S_Kseg0c_A         (.clock(clock), .enable(~hold_a),            .D(r_kseg0c),           .Q(s_kseg0c_a));
    DFF_E #(.WIDTH(3))         S_Kseg0c_B         (.clock(clock), .enable(~hold_b),            .D(r_kseg0c),           .Q(s_kseg0c_b));
    DFF_E #(.WIDTH(1))         S_Use_Kseg0c_A     (.clock(clock), .enable(~hold_a),            .D(r_use_kseg0c_a),     .Q(s_use_kseg0c_a));
    DFF_E #(.WIDTH(1))         S_Use_Kseg0c_B     (.clock(clock), .enable(~hold_b),            .D(r_use_kseg0c_b),     .Q(s_use_kseg0c_b));
    DFF_E #(.WIDTH(1))         S_Hit_A_D          (.clock(clock), .enable(~using_hold_data_a), .D(s_hit_a_e),          .Q(s_hit_a_d));
    DFF_E #(.WIDTH(1))         S_Hit_B_D          (.clock(clock), .enable(~using_hold_data_b), .D(s_hit_b_e),          .Q(s_hit_b_d));
    DFF_E #(.WIDTH(PABITS-12)) S_PFN_A_D          (.clock(clock), .enable(~using_hold_data_a), .D(s_pfn_a_e),          .Q(s_pfn_a_d));
    DFF_E #(.WIDTH(PABITS-12)) S_PFN_B_D          (.clock(clock), .enable(~using_hold_data_b), .D(s_pfn_b_e),          .Q(s_pfn_b_d));
    DFF_E #(.WIDTH(3))         S_C_A_D            (.clock(clock), .enable(~using_hold_data_a), .D(s_c_a_e),            .Q(s_c_a_d));
    DFF_E #(.WIDTH(3))         S_C_B_D            (.clock(clock), .enable(~using_hold_data_b), .D(s_c_b_e),            .Q(s_c_b_d));
    DFF_E #(.WIDTH(1))         S_D_A_D            (.clock(clock), .enable(~using_hold_data_a), .D(s_d_a_e),            .Q(s_d_a_d));
    DFF_E #(.WIDTH(1))         S_D_B_D            (.clock(clock), .enable(~using_hold_data_b), .D(s_d_b_e),            .Q(s_d_b_d));
    DFF_E #(.WIDTH(1))         S_V_A_D            (.clock(clock), .enable(~using_hold_data_a), .D(s_v_a_e),            .Q(s_v_a_d));
    DFF_E #(.WIDTH(1))         S_V_B_D            (.clock(clock), .enable(~using_hold_data_b), .D(s_v_b_e),            .Q(s_v_b_d));
    DFF_E #(.WIDTH(4))         S_Idx_Out_D        (.clock(clock), .enable(~using_hold_data_b), .D(s_idx_out_e),        .Q(s_idx_out_d));
    DFF_E #(.WIDTH(19))        S_VPN2_Out_D       (.clock(clock), .enable(~using_hold_data_b), .D(s_vpn2_out_e),       .Q(s_vpn2_out_d));
    DFF_E #(.WIDTH(16))        S_Mask_Out_D       (.clock(clock), .enable(~using_hold_data_b), .D(s_mask_out_e),       .Q(s_mask_out_d));
    DFF_E #(.WIDTH(8))         S_ASID_Out_D       (.clock(clock), .enable(~using_hold_data_b), .D(s_asid_out_e),       .Q(s_asid_out_d));
    DFF_E #(.WIDTH(1))         S_G_Out_D          (.clock(clock), .enable(~using_hold_data_b), .D(s_g_out_e),          .Q(s_g_out_d));
    DFF_E #(.WIDTH(PABITS-12)) S_PFN0_Out_D       (.clock(clock), .enable(~using_hold_data_b), .D(s_pfn0_out_e),       .Q(s_pfn0_out_d));
    DFF_E #(.WIDTH(3))         S_C0_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_c0_out_e),         .Q(s_c0_out_d));
    DFF_E #(.WIDTH(1))         S_D0_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_d0_out_e),         .Q(s_d0_out_d));
    DFF_E #(.WIDTH(1))         S_V0_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_v0_out_e),         .Q(s_v0_out_d));
    DFF_E #(.WIDTH(PABITS-12)) S_PFN1_Out_D       (.clock(clock), .enable(~using_hold_data_b), .D(s_pfn1_out_e),       .Q(s_pfn1_out_d));
    DFF_E #(.WIDTH(3))         S_C1_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_c1_out_e),         .Q(s_c1_out_d));
    DFF_E #(.WIDTH(1))         S_D1_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_d1_out_e),         .Q(s_d1_out_d));
    DFF_E #(.WIDTH(1))         S_V1_Out_D         (.clock(clock), .enable(~using_hold_data_b), .D(s_v1_out_e),         .Q(s_v1_out_d));

    // Content-Addressable Memory
    TLB_CAM_DP_16 CAM (
        .clock         (clock),             // input clock
        .Idx_Index     (CAM_Idx_Index),     // input [3 : 0] Idx_Index
        .Idx_Write     (CAM_Idx_Write),     // input Idx_Write
        .Idx_VPN2      (CAM_Idx_VPN2),      // input [18 : 0] Idx_VPN2
        .Idx_Mask      (CAM_Idx_Mask),      // input [15 : 0] Idx_Mask
        .Idx_ASID      (CAM_Idx_ASID),      // input [7 : 0] Idx_ASID
        .Idx_G         (CAM_Idx_G),         // input Idx_G
        .Idx_VPN2_Out  (CAM_Idx_VPN2_Out),  // output [18 : 0] Idx_VPN2_Out
        .Idx_Mask_Out  (CAM_Idx_Mask_Out),  // output [15 : 0] Idx_Mask_Out
        .Idx_ASID_Out  (CAM_Idx_ASID_Out),  // output [7 : 0] Idx_ASID_Out
        .Idx_G_Out     (CAM_Idx_G_Out),     // output Idx_G_Out
        .VPN_A         (CAM_VPN_A),         // input [19 : 0] VPN_A
        .ASID_A        (CAM_ASID_A),        // input [7 : 0] ASID_A
        .Hit_A         (CAM_Match_A),       // output Match_A
        .Index_A       (CAM_MatchIndex_A),  // output [3 : 0] MatchIndex_A
        .OddPage_A     (CAM_OddPage_A),     // output OddPage_A
        .Mask_A        (CAM_Mask_A),        // output [15 : 0] Mask_A
        .VPN_B         (CAM_VPN_B),         // input [19 : 0] VPN_B
        .ASID_B        (CAM_ASID_B),        // input [7 : 0] ASID_B
        .Hit_B         (CAM_Match_B),       // output Match_B
        .Index_B       (CAM_MatchIndex_B),  // output [3 : 0] MatchIndex_B
        .OddPage_B     (CAM_OddPage_B),     // output OddPage_B
        .Mask_B        (CAM_Mask_B)         // output [15 : 0] Mask_B
    );

    // Dual-port generic RAM
    RAM_TDP_ZI #(
        .DATA_WIDTH (((2*(PABITS-12))+10)),
        .ADDR_WIDTH (4))
        TLBRAM (
        .clk    (clock),     // input clk
        .rst    (reset),     // input rst
        .addra  (RAM_addra), // input [3 : 0] addra
        .wea    (RAM_wea),   // input wea
        .dina   (RAM_dina),  // input [? : 0] dina
        .douta  (RAM_douta), // output [? : 0] douta
        .addrb  (RAM_addrb), // input [3 : 0] addrb
        .web    (RAM_web),   // input web
        .dinb   (RAM_dinb),  // input [? : 0] dinb
        .doutb  (RAM_doutb)  // output [? : 0] doutb
    );

endmodule

