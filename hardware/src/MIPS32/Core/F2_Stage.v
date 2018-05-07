`timescale 1ns / 1ps
/*
 * File         : F2_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the first and second
 *   Instruction Fetch stages.
 */
module F2_Stage(
    input         clock,
    input         reset,
    input         F1_Issued,
    input         F1_Exception,
    input  [4:0]  F1_ExcCode,
    input         F2_Stall,
    input         F2_Flush,
    input  [31:0] F1_PC,
    input  [31:0] F1_PCAdd4,
    input         F1_DoICacheOp,
    input         F1_XOP_Restart,
    output        F2_F1Issued,
    output [31:0] F2_FetchPC,
    output [31:0] F2_PCAdd4,
    output        F2_F1Exception,
    output [4:0]  F2_F1ExcCode,
    output        F2_F1DoICacheOp,
    output        F2_XOP_Restart
    );

    wire en = ~F2_Stall | F2_Flush;

    DFF_SRE #(.WIDTH(1))  Issued      (.clock(clock), .reset(reset), .enable(en), .D(F1_Issued),      .Q(F2_F1Issued));
    DFF_E   #(.WIDTH(32)) FetchPC     (.clock(clock),                .enable(en), .D(F1_PC),          .Q(F2_FetchPC));
    DFF_E   #(.WIDTH(32)) PCAdd4      (.clock(clock),                .enable(en), .D(F1_PCAdd4),      .Q(F2_PCAdd4));
    DFF_SRE #(.WIDTH(1))  Exception   (.clock(clock), .reset(reset), .enable(en), .D(F1_Exception),   .Q(F2_F1Exception));
    DFF_E   #(.WIDTH(5))  ExcCode     (.clock(clock),                .enable(en), .D(F1_ExcCode),     .Q(F2_F1ExcCode));
    DFF_SRE #(.WIDTH(1))  DoICacheOp  (.clock(clock), .reset(reset), .enable(en), .D(F1_DoICacheOp),  .Q(F2_F1DoICacheOp));
    DFF_E   #(.WIDTH(1))  XOP_Restart (.clock(clock),                .enable(en), .D(F1_XOP_Restart), .Q(F2_XOP_Restart));

endmodule

