`timescale 1ns / 1ps
/*
 * File         : F1_Stage.v
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
module F1_Stage #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    input                  F1_Stall,
    input                  F1_Flush,
    input  [31:0]          D2_PC,
    input                  W1_DoICacheOp,
    input  [2:0]           W1_ICacheOp,
    input  [(PABITS-11):0] W1_ICacheOpData,
    input                  W1_XOP_Restart,
    output [31:0]          F1_PC,
    output                 F1_DoICacheOp,
    output [2:0]           F1_ICacheOp,
    output [(PABITS-11):0] F1_ICacheOpData,
    output                 F1_XOP_Restart
    );

    wire en = ~F1_Stall | F1_Flush;
    wire xop_restart_2cyc = W1_XOP_Restart | F1_DoICacheOp;  // Signal is high for two stages: i-cache op then restart

    DFF_E   #(.WIDTH(32))        PC           (.clock(clock),                .enable(en), .D(D2_PC),            .Q(F1_PC));
    DFF_SRE #(.WIDTH(1))         DoICacheOp   (.clock(clock), .reset(reset), .enable(en), .D(W1_DoICacheOp),    .Q(F1_DoICacheOp));
    DFF_E   #(.WIDTH(3))         ICacheOp     (.clock(clock),                .enable(en), .D(W1_ICacheOp),      .Q(F1_ICacheOp));
    DFF_E   #(.WIDTH(PABITS-10)) ICacheOpData (.clock(clock),                .enable(en), .D(W1_ICacheOpData),  .Q(F1_ICacheOpData));
    DFF_E   #(.WIDTH(1))         XOP_Restart  (.clock(clock),                .enable(en), .D(xop_restart_2cyc), .Q(F1_XOP_Restart));

endmodule

