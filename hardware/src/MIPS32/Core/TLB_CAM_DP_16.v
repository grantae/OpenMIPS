`timescale 1ns / 1ps
/*
 * File         : TLB_CAM_DP_16.v
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
 *   A 16-entry Dual-Port Content-Addressable Memory (CAM) for the MIPS32r1 TLB.
 *   All output data is available on the same cycle (only writes are clocked).
 */
module TLB_CAM_DP_16(
    input  clock,
    // Port A Index
    input  [3:0]  Idx_Index,
    input         Idx_Write,
    input  [18:0] Idx_VPN2,
    input  [15:0] Idx_Mask,
    input  [7:0]  Idx_ASID,
    input         Idx_G,
    output [18:0] Idx_VPN2_Out,
    output [15:0] Idx_Mask_Out,
    output [7:0]  Idx_ASID_Out,
    output        Idx_G_Out,
    // Port A CAM
    input  [19:0] VPN_A,
    input  [7:0]  ASID_A,
    output        Hit_A,
    output [3:0]  Index_A,
    output        OddPage_A,
    output reg [15:0] Mask_A,
    // Port B CAM
    input  [19:0] VPN_B,
    input  [7:0]  ASID_B,
    output        Hit_B,
    output [3:0]  Index_B,
    output        OddPage_B,
    output reg [15:0] Mask_B
    );

    wire [43:0] CAM_data_in = {Idx_VPN2, Idx_Mask, Idx_ASID, Idx_G};
    wire [43:0] CAM_data_out [0:15];
    reg  [43:0] Idx_out;
    reg  [15:0] CAM_Write;
    wire [15:0] CAM_Match_A;
    wire [15:0] CAM_Match_B;
    wire [15:0] CAM_OddPage_A;
    wire [15:0] CAM_OddPage_B;

    assign Idx_VPN2_Out = Idx_out[43:25];
    assign Idx_Mask_Out = Idx_out[24:9];
    assign Idx_ASID_Out = Idx_out[8:1];
    assign Idx_G_Out    = Idx_out[0];
    assign OddPage_A    = |{CAM_OddPage_A & CAM_Match_A};
    assign OddPage_B    = |{CAM_OddPage_B & CAM_Match_B};

    // 16 CAM Entries
    generate
        genvar c;
        for (c = 0; c < 16; c = c + 1) begin: CAM
            TLB_CAM_Entry_DP Entry (
                .clock      (clock),
                .Data_In    (CAM_data_in),
                .Data_Out   (CAM_data_out[c]),
                .Write      (CAM_Write[c]),
                .VPN_A      (VPN_A),
                .ASID_A     (ASID_A),
                .Match_A    (CAM_Match_A[c]),
                .OddPage_A  (CAM_OddPage_A[c]),
                .VPN_B      (VPN_B),
                .ASID_B     (ASID_B),
                .Match_B    (CAM_Match_B[c]),
                .OddPage_B  (CAM_OddPage_B[c])
            );
        end
    endgenerate

    // Index decoder for CAM reads and writes
    always @(*) begin
        CAM_Write = {16{1'b0}};
        case(Idx_Index)
            4'h0: begin Idx_out = CAM_data_out[0];  CAM_Write[0]  = Idx_Write; end
            4'h1: begin Idx_out = CAM_data_out[1];  CAM_Write[1]  = Idx_Write; end
            4'h2: begin Idx_out = CAM_data_out[2];  CAM_Write[2]  = Idx_Write; end
            4'h3: begin Idx_out = CAM_data_out[3];  CAM_Write[3]  = Idx_Write; end
            4'h4: begin Idx_out = CAM_data_out[4];  CAM_Write[4]  = Idx_Write; end
            4'h5: begin Idx_out = CAM_data_out[5];  CAM_Write[5]  = Idx_Write; end
            4'h6: begin Idx_out = CAM_data_out[6];  CAM_Write[6]  = Idx_Write; end
            4'h7: begin Idx_out = CAM_data_out[7];  CAM_Write[7]  = Idx_Write; end
            4'h8: begin Idx_out = CAM_data_out[8];  CAM_Write[8]  = Idx_Write; end
            4'h9: begin Idx_out = CAM_data_out[9];  CAM_Write[9]  = Idx_Write; end
            4'ha: begin Idx_out = CAM_data_out[10]; CAM_Write[10] = Idx_Write; end
            4'hb: begin Idx_out = CAM_data_out[11]; CAM_Write[11] = Idx_Write; end
            4'hc: begin Idx_out = CAM_data_out[12]; CAM_Write[12] = Idx_Write; end
            4'hd: begin Idx_out = CAM_data_out[13]; CAM_Write[13] = Idx_Write; end
            4'he: begin Idx_out = CAM_data_out[14]; CAM_Write[14] = Idx_Write; end
            4'hf: begin Idx_out = CAM_data_out[15]; CAM_Write[15] = Idx_Write; end
        endcase
    end

    // Page mask selector for port A
    always @(*) begin
        case(CAM_Match_A)
            16'h0001:   Mask_A = CAM_data_out[0][24:9];
            16'h0002:   Mask_A = CAM_data_out[1][24:9];
            16'h0004:   Mask_A = CAM_data_out[2][24:9];
            16'h0008:   Mask_A = CAM_data_out[3][24:9];
            16'h0010:   Mask_A = CAM_data_out[4][24:9];
            16'h0020:   Mask_A = CAM_data_out[5][24:9];
            16'h0040:   Mask_A = CAM_data_out[6][24:9];
            16'h0080:   Mask_A = CAM_data_out[7][24:9];
            16'h0100:   Mask_A = CAM_data_out[8][24:9];
            16'h0200:   Mask_A = CAM_data_out[9][24:9];
            16'h0400:   Mask_A = CAM_data_out[10][24:9];
            16'h0800:   Mask_A = CAM_data_out[11][24:9];
            16'h1000:   Mask_A = CAM_data_out[12][24:9];
            16'h2000:   Mask_A = CAM_data_out[13][24:9];
            16'h4000:   Mask_A = CAM_data_out[14][24:9];
            16'h8000:   Mask_A = CAM_data_out[15][24:9];
            default:    Mask_A = {16{1'bx}};
        endcase
    end

    // Page mask selector for port B
    always @(*) begin
        case(CAM_Match_B)
            16'h0001:   Mask_B = CAM_data_out[0][24:9];
            16'h0002:   Mask_B = CAM_data_out[1][24:9];
            16'h0004:   Mask_B = CAM_data_out[2][24:9];
            16'h0008:   Mask_B = CAM_data_out[3][24:9];
            16'h0010:   Mask_B = CAM_data_out[4][24:9];
            16'h0020:   Mask_B = CAM_data_out[5][24:9];
            16'h0040:   Mask_B = CAM_data_out[6][24:9];
            16'h0080:   Mask_B = CAM_data_out[7][24:9];
            16'h0100:   Mask_B = CAM_data_out[8][24:9];
            16'h0200:   Mask_B = CAM_data_out[9][24:9];
            16'h0400:   Mask_B = CAM_data_out[10][24:9];
            16'h0800:   Mask_B = CAM_data_out[11][24:9];
            16'h1000:   Mask_B = CAM_data_out[12][24:9];
            16'h2000:   Mask_B = CAM_data_out[13][24:9];
            16'h4000:   Mask_B = CAM_data_out[14][24:9];
            16'h8000:   Mask_B = CAM_data_out[15][24:9];
            default:    Mask_B = {16{1'bx}};
        endcase
    end

    PriorityEncoder_16x4 Encoder_A (
        .Encoder_In   (CAM_Match_A), // input [15 : 0] Encoder_In
        .Address_Out  (Index_A),     // output [3 : 0] Address_Out
        .Match        (Hit_A)        // output Match
    );

    PriorityEncoder_16x4 Encoder_B (
        .Encoder_In   (CAM_Match_B), // input [15 : 0] Encoder_In
        .Address_Out  (Index_B),     // output [3 : 0] Address_Out
        .Match        (Hit_B)        // output Match
    );

endmodule

