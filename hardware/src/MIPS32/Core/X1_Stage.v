`timescale 1ns / 1ps
/*
 * File         : X1_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the first and second
 *   Instruction Decode stages.
 */
module X1_Stage(
    input         clock,
    input         reset,
    input         D2_Issued,
    input         D2_Exception,
    input  [4:0]  D2_ExcCode,
    input         X1_Stall,
    input         X1_Flush,
    input  [31:0] D2_RestartPC,
    input         D2_IsBDS,
    input  [5:0]  D2_X1_DP_Hazards,
    input  [4:0]  D2_Rs,
    input  [4:0]  D2_Rt,
    input  [31:0] D2_ReadData1,
    input  [31:0] D2_ReadData2,
    input  [31:0] X1_ReadData1_Fwd,
    input  [31:0] X1_ReadData2_Fwd,
    input  [31:0] D2_SZExtImm,
    input         D2_ALUSrcImm,
    input         D2_Movn,
    input         D2_Movz,
    input         D2_Trap,
    input         D2_TrapCond,
    input         D2_RegDst,
    input         D2_LLSC,
    input         D2_MemRead,
    input         D2_MemWrite,
    input         D2_MemHalf,
    input         D2_MemByte,
    input         D2_Left,
    input         D2_Right,
    input         D2_MemSignExtend,
    input         D2_Link,
    input         D2_LinkReg,
    input         D2_RegWrite,
    input         D2_HiRead,
    input         D2_LoRead,
    input         D2_HiWrite,
    input         D2_LoWrite,
    input         D2_MemToReg,
    input  [5:0]  D2_ALUOp,
    input         D2_Mtc0,
    input         D2_TLBp,
    input         D2_TLBr,
    input         D2_TLBwi,
    input         D2_TLBwr,
    input         D2_ICacheOp,
    input         D2_DCacheOp,
    input         D2_Eret,
    input         D2_XOP,
    input  [31:0] D2_BadVAddr,
    output        X1_D2Issued,
    output        X1_D2Exception,
    output [4:0]  X1_D2ExcCode,
    output [31:0] X1_RestartPC,
    output        X1_IsBDS,
    output [5:0]  X1_DP_Hazards,
    output [4:0]  X1_Rs,
    output [4:0]  X1_Rt,
    output [31:0] X1_ReadData1,
    output [31:0] X1_ReadData2,
    output [31:0] X1_SZExtImm,
    output        X1_ALUSrcImm,
    output        X1_Movn,
    output        X1_Movz,
    output        X1_Trap,
    output        X1_TrapCond,
    output        X1_RegDst,
    output        X1_LLSC,
    output        X1_MemRead,
    output        X1_MemWrite,
    output        X1_MemHalf,
    output        X1_MemByte,
    output        X1_Left,
    output        X1_Right,
    output        X1_MemSignExtend,
    output        X1_Link,
    output        X1_LinkReg,
    output        X1_RegWrite,
    output        X1_HiRead,
    output        X1_LoRead,
    output        X1_HiWrite,
    output        X1_LoWrite,
    output        X1_MemToReg,
    output [5:0]  X1_ALUOp,
    output        X1_Mtc0,
    output        X1_TLBp,
    output        X1_TLBr,
    output        X1_TLBwi,
    output        X1_TLBwr,
    output        X1_ICacheOp,
    output        X1_DCacheOp,
    output        X1_Eret,
    output        X1_XOP,
    output [31:0] X1_BadVAddr
    );

    wire en = ~X1_Stall | X1_Flush;
    wire [31:0] Data1 = (X1_Stall) ? X1_ReadData1_Fwd : D2_ReadData1;
    wire [31:0] Data2 = (X1_Stall) ? X1_ReadData2_Fwd : D2_ReadData2;

    // These signals are used for conditions in later pipeline stages.
    // It hurts timing to compare with W1_Issued, so we mask them earlier.
    wire mtc0  = D2_Mtc0  & D2_Issued;
    wire tlbp  = D2_TLBp  & D2_Issued;
    wire tlbr  = D2_TLBr  & D2_Issued;
    wire tlbwi = D2_TLBwi & D2_Issued;
    wire tlbwr = D2_TLBwr & D2_Issued;

    DFF_SRE #(.WIDTH(1))  Issued        (.clock(clock), .reset(reset), .enable(en),   .D(D2_Issued),        .Q(X1_D2Issued));
    DFF_SRE #(.WIDTH(1))  Exception     (.clock(clock), .reset(reset), .enable(en),   .D(D2_Exception),     .Q(X1_D2Exception));
    DFF_E   #(.WIDTH(5))  ExcCode       (.clock(clock),                .enable(en),   .D(D2_ExcCode),       .Q(X1_D2ExcCode));
    DFF_E   #(.WIDTH(32)) RestartPC     (.clock(clock),                .enable(en),   .D(D2_RestartPC),     .Q(X1_RestartPC));
    DFF_E   #(.WIDTH(1))  IsBDS         (.clock(clock),                .enable(en),   .D(D2_IsBDS),         .Q(X1_IsBDS));
    DFF_E   #(.WIDTH(6))  DPHazards     (.clock(clock),                .enable(en),   .D(D2_X1_DP_Hazards), .Q(X1_DP_Hazards));
    DFF_E   #(.WIDTH(5))  Rs            (.clock(clock),                .enable(en),   .D(D2_Rs),            .Q(X1_Rs));
    DFF_E   #(.WIDTH(5))  Rt            (.clock(clock),                .enable(en),   .D(D2_Rt),            .Q(X1_Rt));
    DFF_E   #(.WIDTH(32)) ReadData1     (.clock(clock),                .enable(1'b1), .D(Data1),            .Q(X1_ReadData1));
    DFF_E   #(.WIDTH(32)) ReadData2     (.clock(clock),                .enable(1'b1), .D(Data2),            .Q(X1_ReadData2));
    DFF_E   #(.WIDTH(32)) SZExtImm      (.clock(clock),                .enable(en),   .D(D2_SZExtImm),      .Q(X1_SZExtImm));
    DFF_E   #(.WIDTH(1))  ALUSrcImm     (.clock(clock),                .enable(en),   .D(D2_ALUSrcImm),     .Q(X1_ALUSrcImm));
    DFF_E   #(.WIDTH(1))  Movn          (.clock(clock),                .enable(en),   .D(D2_Movn),          .Q(X1_Movn));
    DFF_E   #(.WIDTH(1))  Movz          (.clock(clock),                .enable(en),   .D(D2_Movz),          .Q(X1_Movz));
    DFF_E   #(.WIDTH(1))  Trap          (.clock(clock),                .enable(en),   .D(D2_Trap),          .Q(X1_Trap));
    DFF_E   #(.WIDTH(1))  TrapCond      (.clock(clock),                .enable(en),   .D(D2_TrapCond),      .Q(X1_TrapCond));
    DFF_E   #(.WIDTH(1))  RegDst        (.clock(clock),                .enable(en),   .D(D2_RegDst),        .Q(X1_RegDst));
    DFF_E   #(.WIDTH(1))  LLSC          (.clock(clock),                .enable(en),   .D(D2_LLSC),          .Q(X1_LLSC));
    DFF_E   #(.WIDTH(1))  MemRead       (.clock(clock),                .enable(en),   .D(D2_MemRead),       .Q(X1_MemRead));
    DFF_E   #(.WIDTH(1))  MemWrite      (.clock(clock),                .enable(en),   .D(D2_MemWrite),      .Q(X1_MemWrite));
    DFF_E   #(.WIDTH(1))  MemHalf       (.clock(clock),                .enable(en),   .D(D2_MemHalf),       .Q(X1_MemHalf));
    DFF_E   #(.WIDTH(1))  MemByte       (.clock(clock),                .enable(en),   .D(D2_MemByte),       .Q(X1_MemByte));
    DFF_E   #(.WIDTH(1))  Left          (.clock(clock),                .enable(en),   .D(D2_Left),          .Q(X1_Left));
    DFF_E   #(.WIDTH(1))  Right         (.clock(clock),                .enable(en),   .D(D2_Right),         .Q(X1_Right));
    DFF_E   #(.WIDTH(1))  MemSignExtend (.clock(clock),                .enable(en),   .D(D2_MemSignExtend), .Q(X1_MemSignExtend));
    DFF_E   #(.WIDTH(1))  Link          (.clock(clock),                .enable(en),   .D(D2_Link),          .Q(X1_Link));
    DFF_E   #(.WIDTH(1))  LinkReg       (.clock(clock),                .enable(en),   .D(D2_LinkReg),       .Q(X1_LinkReg));
    DFF_E   #(.WIDTH(1))  RegWrite      (.clock(clock),                .enable(en),   .D(D2_RegWrite),      .Q(X1_RegWrite));
    DFF_E   #(.WIDTH(1))  HiRead        (.clock(clock),                .enable(en),   .D(D2_HiRead),        .Q(X1_HiRead));
    DFF_E   #(.WIDTH(1))  LoRead        (.clock(clock),                .enable(en),   .D(D2_LoRead),        .Q(X1_LoRead));
    DFF_E   #(.WIDTH(1))  HiWrite       (.clock(clock),                .enable(en),   .D(D2_HiWrite),       .Q(X1_HiWrite));
    DFF_E   #(.WIDTH(1))  LoWrite       (.clock(clock),                .enable(en),   .D(D2_LoWrite),       .Q(X1_LoWrite));
    DFF_E   #(.WIDTH(1))  MemToReg      (.clock(clock),                .enable(en),   .D(D2_MemToReg),      .Q(X1_MemToReg));
    DFF_E   #(.WIDTH(6))  ALUOp         (.clock(clock),                .enable(en),   .D(D2_ALUOp),         .Q(X1_ALUOp));
    DFF_E   #(.WIDTH(1))  Mtc0          (.clock(clock),                .enable(en),   .D(mtc0),             .Q(X1_Mtc0));
    DFF_E   #(.WIDTH(1))  TLBp          (.clock(clock),                .enable(en),   .D(tlbp),             .Q(X1_TLBp));
    DFF_E   #(.WIDTH(1))  TLBr          (.clock(clock),                .enable(en),   .D(tlbr),             .Q(X1_TLBr));
    DFF_E   #(.WIDTH(1))  TLBwi         (.clock(clock),                .enable(en),   .D(tlbwi),            .Q(X1_TLBwi));
    DFF_E   #(.WIDTH(1))  TLBwr         (.clock(clock),                .enable(en),   .D(tlbwr),            .Q(X1_TLBwr));
    DFF_E   #(.WIDTH(1))  ICacheOp      (.clock(clock),                .enable(en),   .D(D2_ICacheOp),      .Q(X1_ICacheOp));
    DFF_E   #(.WIDTH(1))  DCacheOp      (.clock(clock),                .enable(en),   .D(D2_DCacheOp),      .Q(X1_DCacheOp));
    DFF_E   #(.WIDTH(1))  Eret          (.clock(clock),                .enable(en),   .D(D2_Eret),          .Q(X1_Eret));
    DFF_E   #(.WIDTH(1))  XOP           (.clock(clock),                .enable(en),   .D(D2_XOP),           .Q(X1_XOP));
    DFF_E   #(.WIDTH(32)) BadVAddr      (.clock(clock),                .enable(en),   .D(D2_BadVAddr),      .Q(X1_BadVAddr));

endmodule

