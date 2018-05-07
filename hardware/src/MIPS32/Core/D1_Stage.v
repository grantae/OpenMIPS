`timescale 1ns / 1ps
/*
 * File         : D1_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the second Instruction Fetch
 *   and first Instruction Decode stages.
 */
module D1_Stage(
    input         clock,
    input         reset,
    input         F2_Issued,
    input         F2_Exception,
    input  [4:0]  F2_ExcCode,
    input         D1_Stall,
    input         D1_Flush,
    input         F2_IsBDS,
    input  [31:0] F2_Instruction,
    input  [31:0] F2_FetchPC,
    input  [31:0] F2_PCAdd4,
    input         F2_XOP_Restart,
    output        D1_F2Issued,
    output [31:0] D1_Instruction,
    output [31:0] D1_FetchPC,   // Will be the final restart PC if F2_IsBDS is high
    output        D1_F2IsBDS,
    output [31:0] D1_PCAdd4,
    output        D1_F2Exception,
    output [4:0]  D1_F2ExcCode,
    output        D1_XOP_Restart
    );

    wire en = ~D1_Stall | D1_Flush;
    wire restart_en = &{en, F2_Issued, ~F2_IsBDS};

    DFF_SRE #(.WIDTH(1))  Issued      (.clock(clock), .reset(reset), .enable(en),         .D(F2_Issued),      .Q(D1_F2Issued));
    DFF_E   #(.WIDTH(32)) Instruction (.clock(clock),                .enable(en),         .D(F2_Instruction), .Q(D1_Instruction));
    DFF_E   #(.WIDTH(32)) FetchPC     (.clock(clock),                .enable(restart_en), .D(F2_FetchPC),     .Q(D1_FetchPC));
    DFF_E   #(.WIDTH(1))  IsBDS       (.clock(clock),                .enable(en),         .D(F2_IsBDS),       .Q(D1_F2IsBDS));
    DFF_E   #(.WIDTH(32)) PCAdd4      (.clock(clock),                .enable(en),         .D(F2_PCAdd4),      .Q(D1_PCAdd4));
    DFF_SRE #(.WIDTH(1))  Exception   (.clock(clock), .reset(reset), .enable(en),         .D(F2_Exception),   .Q(D1_F2Exception));
    DFF_E   #(.WIDTH(5))  ExcCode     (.clock(clock),                .enable(en),         .D(F2_ExcCode),     .Q(D1_F2ExcCode));
    DFF_E   #(.WIDTH(1))  XOP_Restart (.clock(clock),                .enable(en),         .D(F2_XOP_Restart), .Q(D1_XOP_Restart));

endmodule

