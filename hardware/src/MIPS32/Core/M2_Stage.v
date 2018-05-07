`timescale 1ns / 1ps
/*
 * File         : M2_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the first and second
 *   Memory stages.
 */
module M2_Stage(
    input         clock,
    input         reset,
    input         M1_Issued,
    input         M1_Exception,
    input  [4:0]  M1_ExcCode,
    input         M2_Stall,
    input         M2_Flush,
    input  [31:0] M1_RestartPC,
    input         M1_IsBDS,
    input  [4:0]  M1_RtRd,
    input  [2:0]  M1_CP0Sel,
    input         M1_LLSC,
    input         M1_MemRead,
    input         M1_MemReadIssued,
    input         M1_MemWrite,
    input         M1_MemWriteIssued,
    input         M1_MemHalf,
    input         M1_MemByte,
    input         M1_Left,
    input         M1_Right,
    input         M1_MemSignExtend,
    input         M1_BigEndian,
    input         M1_Div,
    input         M1_RegWrite,
    input         M1_HiWrite,
    input         M1_LoWrite,
    input         M1_MemToReg,
    input  [31:0] M1_ALUResult,
    input  [31:0] M1_UnalignedReg,
    input         M1_Mtc0,
    input         M1_TLBp,
    input         M1_TLBr,
    input         M1_TLBwi,
    input         M1_TLBwr,
    input         M1_ICacheOp,
    input         M1_Eret,
    input         M1_XOP,
    input  [31:0] M1_BadVAddr,
    output        M2_M1Issued,
    output        M2_M1Exception,
    output [4:0]  M2_M1ExcCode,
    output [31:0] M2_RestartPC,
    output        M2_IsBDS,
    output [4:0]  M2_RtRd,
    output [2:0]  M2_CP0Sel,
    output        M2_LLSC,
    output        M2_MemRead,
    output        M2_MemReadIssued,
    output        M2_MemWrite,
    output        M2_MemWriteIssued,
    output        M2_MemHalf,
    output        M2_MemByte,
    output        M2_Left,
    output        M2_Right,
    output        M2_MemSignExtend,
    output        M2_BigEndian,
    output        M2_Div,
    output        M2_RegWrite,
    output        M2_HiWrite,
    output        M2_LoWrite,
    output        M2_MemToReg,
    output [31:0] M2_ALUResult,
    output [31:0] M2_UnalignedReg,
    output        M2_Mtc0,
    output        M2_TLBp,
    output        M2_TLBr,
    output        M2_TLBwi,
    output        M2_TLBwr,
    output        M2_ICacheOp,
    output        M2_Eret,
    output        M2_XOP,
    output [31:0] M2_BadVAddr
    );

    wire en = ~M2_Stall | M2_Flush;

    DFF_SRE #(.WIDTH(1))  Issued         (.clock(clock), .reset(reset), .enable(en), .D(M1_Issued),         .Q(M2_M1Issued));
    DFF_SRE #(.WIDTH(1))  Exception      (.clock(clock), .reset(reset), .enable(en), .D(M1_Exception),      .Q(M2_M1Exception));
    DFF_E   #(.WIDTH(5))  ExcCode        (.clock(clock),                .enable(en), .D(M1_ExcCode),        .Q(M2_M1ExcCode));
    DFF_E   #(.WIDTH(32)) RestartPC      (.clock(clock),                .enable(en), .D(M1_RestartPC),      .Q(M2_RestartPC));
    DFF_E   #(.WIDTH(1))  IsBDS          (.clock(clock),                .enable(en), .D(M1_IsBDS),          .Q(M2_IsBDS));
    DFF_E   #(.WIDTH(5))  RtRd           (.clock(clock),                .enable(en), .D(M1_RtRd),           .Q(M2_RtRd));
    DFF_E   #(.WIDTH(3))  CP0Sel         (.clock(clock),                .enable(en), .D(M1_CP0Sel),         .Q(M2_CP0Sel));
    DFF_E   #(.WIDTH(1))  LLSC           (.clock(clock),                .enable(en), .D(M1_LLSC),           .Q(M2_LLSC));
    DFF_E   #(.WIDTH(1))  MemRead        (.clock(clock),                .enable(en), .D(M1_MemRead),        .Q(M2_MemRead));
    DFF_E   #(.WIDTH(1))  MemReadIssued  (.clock(clock),                .enable(en), .D(M1_MemReadIssued),  .Q(M2_MemReadIssued));
    DFF_E   #(.WIDTH(1))  MemWrite       (.clock(clock),                .enable(en), .D(M1_MemWrite),       .Q(M2_MemWrite));
    DFF_E   #(.WIDTH(1))  MemWriteIssued (.clock(clock),                .enable(en), .D(M1_MemWriteIssued), .Q(M2_MemWriteIssued));
    DFF_E   #(.WIDTH(1))  MemHalf        (.clock(clock),                .enable(en), .D(M1_MemHalf),        .Q(M2_MemHalf));
    DFF_E   #(.WIDTH(1))  MemByte        (.clock(clock),                .enable(en), .D(M1_MemByte),        .Q(M2_MemByte));
    DFF_E   #(.WIDTH(1))  Left           (.clock(clock),                .enable(en), .D(M1_Left),           .Q(M2_Left));
    DFF_E   #(.WIDTH(1))  Right          (.clock(clock),                .enable(en), .D(M1_Right),          .Q(M2_Right));
    DFF_E   #(.WIDTH(1))  MemSignExtend  (.clock(clock),                .enable(en), .D(M1_MemSignExtend),  .Q(M2_MemSignExtend));
    DFF_E   #(.WIDTH(1))  BigEndian      (.clock(clock),                .enable(en), .D(M1_BigEndian),      .Q(M2_BigEndian));
    DFF_E   #(.WIDTH(1))  Div            (.clock(clock),                .enable(en), .D(M1_Div),            .Q(M2_Div));
    DFF_E   #(.WIDTH(1))  RegWrite       (.clock(clock),                .enable(en), .D(M1_RegWrite),       .Q(M2_RegWrite));
    DFF_E   #(.WIDTH(1))  HiWrite        (.clock(clock),                .enable(en), .D(M1_HiWrite),        .Q(M2_HiWrite));
    DFF_E   #(.WIDTH(1))  LoWrite        (.clock(clock),                .enable(en), .D(M1_LoWrite),        .Q(M2_LoWrite));
    DFF_E   #(.WIDTH(1))  MemToReg       (.clock(clock),                .enable(en), .D(M1_MemToReg),       .Q(M2_MemToReg));
    DFF_E   #(.WIDTH(32)) ALUResult      (.clock(clock),                .enable(en), .D(M1_ALUResult),      .Q(M2_ALUResult));
    DFF_E   #(.WIDTH(32)) UnalignedReg   (.clock(clock),                .enable(en), .D(M1_UnalignedReg),   .Q(M2_UnalignedReg));
    DFF_E   #(.WIDTH(1))  Mtc0           (.clock(clock),                .enable(en), .D(M1_Mtc0),           .Q(M2_Mtc0));
    DFF_E   #(.WIDTH(1))  TLBp           (.clock(clock),                .enable(en), .D(M1_TLBp),           .Q(M2_TLBp));
    DFF_E   #(.WIDTH(1))  TLBr           (.clock(clock),                .enable(en), .D(M1_TLBr),           .Q(M2_TLBr));
    DFF_E   #(.WIDTH(1))  TLBwi          (.clock(clock),                .enable(en), .D(M1_TLBwi),          .Q(M2_TLBwi));
    DFF_E   #(.WIDTH(1))  TLBwr          (.clock(clock),                .enable(en), .D(M1_TLBwr),          .Q(M2_TLBwr));
    DFF_E   #(.WIDTH(1))  ICacheOp       (.clock(clock),                .enable(en), .D(M1_ICacheOp),       .Q(M2_ICacheOp));
    DFF_E   #(.WIDTH(1))  Eret           (.clock(clock),                .enable(en), .D(M1_Eret),           .Q(M2_Eret));
    DFF_E   #(.WIDTH(1))  XOP            (.clock(clock),                .enable(en), .D(M1_XOP),            .Q(M2_XOP));
    DFF_E   #(.WIDTH(32)) BadVAddr       (.clock(clock),                .enable(en), .D(M1_BadVAddr),       .Q(M2_BadVAddr));

endmodule

