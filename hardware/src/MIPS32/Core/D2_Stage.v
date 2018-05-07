`timescale 1ns / 1ps
/*
 * File         : D2_Stage.v
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
module D2_Stage(
    input         clock,
    input         reset,
    input         D1_Issued,
    input         D1_Exception,
    input  [4:0]  D1_ExcCode,
    input         D2_Stall,
    input         D2_Flush,
    input         D1_IsBDS,
    input         D1_F2IsBDS,
    input  [31:0] D1_Instruction,
    input  [31:0] D1_FetchPC,
    input  [31:0] D1_ReadData1,
    input  [31:0] D1_ReadData2,
    input  [31:0] D2_ReadData1_Fwd,
    input  [31:0] D2_ReadData2_Fwd,
    input  [31:0] D1_Cp0_ReadData,
    input         D1_XOP_Restart,
    input  [31:0] D1_JumpIBrAddr,
    output        D2_D1Issued,
    output [31:0] D2_Instruction,
    output [31:0] D2_RestartPC,
    output        D2_IsBDS,
    output [31:0] D2_ReadData1,
    output [31:0] D2_ReadData2,
    output [31:0] D2_Cp0_ReadData,
    output        D2_D1Exception,
    output [4:0]  D2_D1ExcCode,
    output [31:0] D2_BadVAddr,
    output        D2_XOP_Restart,
    output [31:0] D2_JumpIBrAddr
    );

    wire en = ~D2_Stall | D2_Flush;
    wire restart_en = &{en, D1_Issued, ~D1_IsBDS};
    wire [31:0] Data1 = (D2_Stall) ? D2_ReadData1_Fwd : D1_ReadData1;
    wire [31:0] Data2 = (D2_Stall) ? D2_ReadData2_Fwd : D1_ReadData2;
    wire BDS = (D1_IsBDS | D1_F2IsBDS);

    DFF_SRE #(.WIDTH(1))  Issued       (.clock(clock), .reset(reset), .enable(en),         .D(D1_Issued),        .Q(D2_D1Issued));
    DFF_E   #(.WIDTH(32)) Instruction  (.clock(clock),                .enable(en),         .D(D1_Instruction),   .Q(D2_Instruction));
    DFF_E   #(.WIDTH(32)) RestartPC    (.clock(clock),                .enable(restart_en), .D(D1_FetchPC),       .Q(D2_RestartPC));
    DFF_E   #(.WIDTH(1))  IsBDS        (.clock(clock),                .enable(en),         .D(BDS),              .Q(D2_IsBDS));
    DFF_E   #(.WIDTH(32)) ReadData1    (.clock(clock),                .enable(1'b1),       .D(Data1),            .Q(D2_ReadData1));
    DFF_E   #(.WIDTH(32)) ReadData2    (.clock(clock),                .enable(1'b1),       .D(Data2),            .Q(D2_ReadData2));
    DFF_E   #(.WIDTH(32)) Cp0_ReadData (.clock(clock),                .enable(en),         .D(D1_Cp0_ReadData),  .Q(D2_Cp0_ReadData));
    DFF_SRE #(.WIDTH(1))  Exception    (.clock(clock), .reset(reset), .enable(en),         .D(D1_Exception),     .Q(D2_D1Exception));
    DFF_E   #(.WIDTH(5))  ExcCode      (.clock(clock),                .enable(en),         .D(D1_ExcCode),       .Q(D2_D1ExcCode));
    DFF_E   #(.WIDTH(32)) BadVAddr     (.clock(clock),                .enable(en),         .D(D1_FetchPC),       .Q(D2_BadVAddr));
    DFF_E   #(.WIDTH(1))  XOP_Restart  (.clock(clock),                .enable(en),         .D(D1_XOP_Restart),   .Q(D2_XOP_Restart));
    DFF_E   #(.WIDTH(32)) JumpIBrAddr  (.clock(clock),                .enable(en),         .D(D1_JumpIBrAddr),   .Q(D2_JumpIBrAddr));

endmodule

