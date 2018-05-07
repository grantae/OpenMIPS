`timescale 1ns / 1ps
/*
 * File         : M1_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the Execute and first
 *   Memory stages.
 */
module M1_Stage(
    input         clock,
    input         reset,
    input         X1_Issued,
    input         X1_Exception,
    input  [4:0]  X1_ExcCode,
    input         M1_Stall,
    input         M1_Flush,
    input  [31:0] X1_RestartPC,
    input         X1_IsBDS,
    input  [1:0]  X1_M1_DP_Hazards,
    input  [4:0]  X1_Rt,
    input  [4:0]  X1_RtRd,
    input  [2:0]  X1_CP0Sel,
    input         X1_Movn,
    input         X1_Movz,
    input         X1_BZero,
    input         X1_Trap,
    input         X1_TrapCond,
    input         X1_LLSC,
    input         X1_MemRead,
    input         X1_MemWrite,
    input         X1_MemHalf,
    input         X1_MemByte,
    input         X1_Left,
    input         X1_Right,
    input         X1_MemSignExtend,
    input         X1_Div,
    input         X1_RegWrite,
    input         X1_HiWrite,
    input         X1_LoWrite,
    input         X1_MemToReg,
    input  [31:0] X1_ALUResult,
    input  [31:0] X1_WriteData,
    input  [31:0] M1_WriteData_Fwd,
    input         X1_Mtc0,
    input         X1_TLBp,
    input         X1_TLBr,
    input         X1_TLBwi,
    input         X1_TLBwr,
    input         X1_ICacheOp,
    input         X1_DCacheOp,
    input         X1_Eret,
    input         X1_XOP,
    input  [31:0] X1_BadVAddr,
    output        M1_X1Issued,
    output        M1_X1Exception,
    output [4:0]  M1_X1ExcCode,
    output [31:0] M1_RestartPC,
    output        M1_IsBDS,
    output [1:0]  M1_DP_Hazards,
    output [4:0]  M1_Rt,
    output [4:0]  M1_RtRd,
    output [2:0]  M1_CP0Sel,
    output        M1_Trap,
    output        M1_TrapCond,
    output        M1_LLSC,
    output        M1_MemRead,
    output        M1_MemWrite,
    output        M1_MemHalf,
    output        M1_MemByte,
    output        M1_Left,
    output        M1_Right,
    output        M1_MemSignExtend,
    output        M1_Div,
    output        M1_RegWrite,
    output        M1_HiWrite,
    output        M1_LoWrite,
    output        M1_MemToReg,
    output [31:0] M1_ALUResult,
    output [31:0] M1_WriteData,
    output        M1_Mtc0,
    output        M1_TLBp,
    output        M1_TLBr,
    output        M1_TLBwi,
    output        M1_TLBwr,
    output        M1_ICacheOp,
    output        M1_DCacheOp,
    output        M1_Eret,
    output        M1_XOP,
    output [31:0] M1_BadVAddr
    );

    wire en = ~M1_Stall | M1_Flush;
    wire regwrite_in = X1_RegWrite & ((~X1_Movn & ~X1_Movz) | (X1_Movn & ~X1_BZero) | (X1_Movz & X1_BZero));
    wire [31:0] Data = (M1_Stall) ? M1_WriteData_Fwd : X1_WriteData;

    DFF_SRE #(.WIDTH(1))  Issued        (.clock(clock), .reset(reset), .enable(en),   .D(X1_Issued),        .Q(M1_X1Issued));
    DFF_SRE #(.WIDTH(1))  Exception     (.clock(clock), .reset(reset), .enable(en),   .D(X1_Exception),     .Q(M1_X1Exception));
    DFF_E   #(.WIDTH(5))  ExcCode       (.clock(clock),                .enable(en),   .D(X1_ExcCode),       .Q(M1_X1ExcCode));
    DFF_E   #(.WIDTH(32)) RestartPC     (.clock(clock),                .enable(en),   .D(X1_RestartPC),     .Q(M1_RestartPC));
    DFF_E   #(.WIDTH(1))  IsBDS         (.clock(clock),                .enable(en),   .D(X1_IsBDS),         .Q(M1_IsBDS));
    DFF_E   #(.WIDTH(2))  DPHazards     (.clock(clock),                .enable(en),   .D(X1_M1_DP_Hazards), .Q(M1_DP_Hazards));
    DFF_E   #(.WIDTH(5))  Rt            (.clock(clock),                .enable(en),   .D(X1_Rt),            .Q(M1_Rt));
    DFF_E   #(.WIDTH(5))  RtRd          (.clock(clock),                .enable(en),   .D(X1_RtRd),          .Q(M1_RtRd));
    DFF_E   #(.WIDTH(3))  CP0Sel        (.clock(clock),                .enable(en),   .D(X1_CP0Sel),        .Q(M1_CP0Sel));
    DFF_E   #(.WIDTH(1))  Trap          (.clock(clock),                .enable(en),   .D(X1_Trap),          .Q(M1_Trap));
    DFF_E   #(.WIDTH(1))  TrapCond      (.clock(clock),                .enable(en),   .D(X1_TrapCond),      .Q(M1_TrapCond));
    DFF_E   #(.WIDTH(1))  LLSC          (.clock(clock),                .enable(en),   .D(X1_LLSC),          .Q(M1_LLSC));
    DFF_E   #(.WIDTH(1))  MemRead       (.clock(clock),                .enable(en),   .D(X1_MemRead),       .Q(M1_MemRead));
    DFF_E   #(.WIDTH(1))  MemWrite      (.clock(clock),                .enable(en),   .D(X1_MemWrite),      .Q(M1_MemWrite));
    DFF_E   #(.WIDTH(1))  MemHalf       (.clock(clock),                .enable(en),   .D(X1_MemHalf),       .Q(M1_MemHalf));
    DFF_E   #(.WIDTH(1))  MemByte       (.clock(clock),                .enable(en),   .D(X1_MemByte),       .Q(M1_MemByte));
    DFF_E   #(.WIDTH(1))  Left          (.clock(clock),                .enable(en),   .D(X1_Left),          .Q(M1_Left));
    DFF_E   #(.WIDTH(1))  Right         (.clock(clock),                .enable(en),   .D(X1_Right),         .Q(M1_Right));
    DFF_E   #(.WIDTH(1))  MemSignExtend (.clock(clock),                .enable(en),   .D(X1_MemSignExtend), .Q(M1_MemSignExtend));
    DFF_E   #(.WIDTH(1))  Div           (.clock(clock),                .enable(en),   .D(X1_Div),           .Q(M1_Div));
    DFF_E   #(.WIDTH(1))  RegWrite      (.clock(clock),                .enable(en),   .D(regwrite_in),      .Q(M1_RegWrite));
    DFF_E   #(.WIDTH(1))  HiWrite       (.clock(clock),                .enable(en),   .D(X1_HiWrite),       .Q(M1_HiWrite));
    DFF_E   #(.WIDTH(1))  LoWrite       (.clock(clock),                .enable(en),   .D(X1_LoWrite),       .Q(M1_LoWrite));
    DFF_E   #(.WIDTH(1))  MemToReg      (.clock(clock),                .enable(en),   .D(X1_MemToReg),      .Q(M1_MemToReg));
    DFF_E   #(.WIDTH(32)) ALUResult     (.clock(clock),                .enable(en),   .D(X1_ALUResult),     .Q(M1_ALUResult));
    DFF_E   #(.WIDTH(32)) WriteData     (.clock(clock),                .enable(1'b1), .D(Data),             .Q(M1_WriteData));
    DFF_E   #(.WIDTH(1))  Mtc0          (.clock(clock),                .enable(en),   .D(X1_Mtc0),          .Q(M1_Mtc0));
    DFF_E   #(.WIDTH(1))  TLBp          (.clock(clock),                .enable(en),   .D(X1_TLBp),          .Q(M1_TLBp));
    DFF_E   #(.WIDTH(1))  TLBr          (.clock(clock),                .enable(en),   .D(X1_TLBr),          .Q(M1_TLBr));
    DFF_E   #(.WIDTH(1))  TLBwi         (.clock(clock),                .enable(en),   .D(X1_TLBwi),         .Q(M1_TLBwi));
    DFF_E   #(.WIDTH(1))  TLBwr         (.clock(clock),                .enable(en),   .D(X1_TLBwr),         .Q(M1_TLBwr));
    DFF_E   #(.WIDTH(1))  ICacheOp      (.clock(clock),                .enable(en),   .D(X1_ICacheOp),      .Q(M1_ICacheOp));
    DFF_E   #(.WIDTH(1))  DCacheOp      (.clock(clock),                .enable(en),   .D(X1_DCacheOp),      .Q(M1_DCacheOp));
    DFF_E   #(.WIDTH(1))  Eret          (.clock(clock),                .enable(en),   .D(X1_Eret),          .Q(M1_Eret));
    DFF_E   #(.WIDTH(1))  XOP           (.clock(clock),                .enable(en),   .D(X1_XOP),           .Q(M1_XOP));
    DFF_E   #(.WIDTH(32)) BadVAddr      (.clock(clock),                .enable(en),   .D(X1_BadVAddr),      .Q(M1_BadVAddr));

endmodule

