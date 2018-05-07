`timescale 1ns / 1ps
/*
 * File         : W1_Stage.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Pipeline Register to bridge the second Memory
 *   stage with the Writeback stage.
 */
module W1_Stage #(parameter PABITS=36) (
    input         clock,
    input         reset,
    input         M2_Issued,
    input         M2_Exception,
    input  [4:0]  M2_ExcCode,
    input         W1_Stall,
    input         W1_Flush,
    input         W1_Issued,
    input  [31:0] M2_RestartPC,
    input         M2_IsBDS,
    input         M2_MemRWIssued,
    input  [4:0]  M2_RtRd,
    input  [2:0]  M2_CP0Sel,
    input         M2_Div,
    input         M2_RegWrite,
    input         M2_HiWrite,
    input         M2_LoWrite,
    input         M2_MemToReg,
    input  [31:0] M2_ALUResult,
    input  [31:0] M2_ReadData,
    input         M2_Mtc0,
    input         M2_TLBp,
    input         M2_TLBr,
    input         M2_TLBwi,
    input         M2_TLBwr,
    input  [3:0]  M2_TLBIndex,
    input         M2_ICacheOp,
    input         M2_Eret,
    input         M2_XOP,
    input         M2_Tlbp_Hit,
    input  [3:0]  M2_Tlbp_Index,
    input  [(29+(2*PABITS)):0] M2_Tlbr_result,
    input  [31:0] M2_BadVAddr,
    output        W1_M2Issued,
    output        W1_M2Exception,
    output [4:0]  W1_M2ExcCode,
    output [31:0] W1_RestartPC,
    output        W1_IsBDS,
    output        W1_M2MemRWIssued,
    output [4:0]  W1_RtRd,
    output [2:0]  W1_CP0Sel,
    output        W1_Div,
    output        W1_RegWrite,
    output        W1_HiWrite,
    output        W1_LoWrite,
    output        W1_MemToReg,
    output [31:0] W1_ALUResult,
    output [31:0] W1_ReadData,
    output        W1_Mtc0,
    output        W1_TLBp,
    output        W1_TLBr,
    output        W1_TLBwi,
    output        W1_TLBwr,
    output [3:0]  W1_TLBIndex,
    output        W1_ICacheOp,
    output        W1_Eret,
    output        W1_XOP,
    output        W1_Tlbp_Hit,
    output [3:0]  W1_Tlbp_Index,
    output [(29+(2*PABITS)):0] W1_Tlbr_result,
    output [31:0] W1_BadVAddr
    );

    wire en = ~W1_Stall | W1_Flush;
    wire rpc_en = ~(W1_Stall | (W1_ICacheOp & W1_Issued));  // Keep it longer during 2-cycle i-cache ops

    DFF_SRE #(.WIDTH(1))  Issued       (.clock(clock), .reset(reset), .enable(en),     .D(M2_Issued),         .Q(W1_M2Issued));
    DFF_SRE #(.WIDTH(1))  Exception    (.clock(clock), .reset(reset), .enable(en),     .D(M2_Exception),      .Q(W1_M2Exception));
    DFF_E   #(.WIDTH(5))  ExcCode      (.clock(clock),                .enable(en),     .D(M2_ExcCode),        .Q(W1_M2ExcCode));
    DFF_E   #(.WIDTH(32)) RestartPC    (.clock(clock),                .enable(rpc_en), .D(M2_RestartPC),      .Q(W1_RestartPC));
    DFF_E   #(.WIDTH(1))  IsBDS        (.clock(clock),                .enable(en),     .D(M2_IsBDS),          .Q(W1_IsBDS));
    DFF_E   #(.WIDTH(1))  MemRWIssued  (.clock(clock),                .enable(en),     .D(M2_MemRWIssued), .Q(W1_M2MemRWIssued));
    DFF_E   #(.WIDTH(5))  RtRd         (.clock(clock),                .enable(en),     .D(M2_RtRd),           .Q(W1_RtRd));
    DFF_E   #(.WIDTH(3))  CP0Sel       (.clock(clock),                .enable(en),     .D(M2_CP0Sel),         .Q(W1_CP0Sel));
    DFF_E   #(.WIDTH(1))  Div          (.clock(clock),                .enable(en),     .D(M2_Div),            .Q(W1_Div));
    DFF_E   #(.WIDTH(1))  RegWrite     (.clock(clock),                .enable(en),     .D(M2_RegWrite),       .Q(W1_RegWrite));
    DFF_E   #(.WIDTH(1))  HiWrite      (.clock(clock),                .enable(en),     .D(M2_HiWrite),        .Q(W1_HiWrite));
    DFF_E   #(.WIDTH(1))  LoWrite      (.clock(clock),                .enable(en),     .D(M2_LoWrite),        .Q(W1_LoWrite));
    DFF_E   #(.WIDTH(1))  MemToReg     (.clock(clock),                .enable(en),     .D(M2_MemToReg),       .Q(W1_MemToReg));
    DFF_E   #(.WIDTH(32)) ALUResult    (.clock(clock),                .enable(en),     .D(M2_ALUResult),      .Q(W1_ALUResult));
    DFF_E   #(.WIDTH(32)) ReadData     (.clock(clock),                .enable(en),     .D(M2_ReadData),       .Q(W1_ReadData));
    DFF_E   #(.WIDTH(1))  Mtc0         (.clock(clock),                .enable(en),     .D(M2_Mtc0),           .Q(W1_Mtc0));
    DFF_E   #(.WIDTH(1))  TLBp         (.clock(clock),                .enable(en),     .D(M2_TLBp),           .Q(W1_TLBp));
    DFF_E   #(.WIDTH(1))  TLBr         (.clock(clock),                .enable(en),     .D(M2_TLBr),           .Q(W1_TLBr));
    DFF_E   #(.WIDTH(1))  TLBwi        (.clock(clock),                .enable(en),     .D(M2_TLBwi),          .Q(W1_TLBwi));
    DFF_E   #(.WIDTH(1))  TLBwr        (.clock(clock),                .enable(en),     .D(M2_TLBwr),          .Q(W1_TLBwr));
    DFF_E   #(.WIDTH(4))  TLBIndex     (.clock(clock),                .enable(en),     .D(M2_TLBIndex),       .Q(W1_TLBIndex));
    DFF_E   #(.WIDTH(1))  ICacheOp     (.clock(clock),                .enable(en),     .D(M2_ICacheOp),       .Q(W1_ICacheOp));
    DFF_E   #(.WIDTH(1))  Eret         (.clock(clock),                .enable(en),     .D(M2_Eret),           .Q(W1_Eret));
    DFF_E   #(.WIDTH(1))  XOP          (.clock(clock),                .enable(en),     .D(M2_XOP),            .Q(W1_XOP));
    DFF_E   #(.WIDTH(1))  Tlbp_Hit     (.clock(clock),                .enable(en),     .D(M2_Tlbp_Hit),       .Q(W1_Tlbp_Hit));
    DFF_E   #(.WIDTH(4))  Tlbp_Index   (.clock(clock),                .enable(en),     .D(M2_Tlbp_Index),     .Q(W1_Tlbp_Index));
    DFF_E   #(.WIDTH((30+(2*PABITS)))) Tlbr_result   (.clock(clock),  .enable(en),     .D(M2_Tlbr_result),    .Q(W1_Tlbr_result));
    DFF_E   #(.WIDTH(32)) BadVAddr     (.clock(clock),                .enable(en),     .D(M2_BadVAddr),       .Q(W1_BadVAddr));

endmodule

