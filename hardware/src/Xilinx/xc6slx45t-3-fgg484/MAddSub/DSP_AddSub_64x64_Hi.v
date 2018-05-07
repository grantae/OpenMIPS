`timescale 1ns / 1ps
/*
 * File         : DSP_AddSub_64x64_Hi.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   7-Jan-2015   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A post-multiply adder/subtractor to handle the
 *   upper 16 bits of a 64-bit computation.
 */
module DSP_AddSub_64x64_High(
    input         clock,
    input         sign,
    input         subtract,
    input  [15:0] A_High,
    input  [15:0] B_High,
    input         CARRYIN,
    input         CEB,
    input         CEC,
    input         CEP,
    input         CEOPMODE,
    output [16:0] S
    );

    wire [47:0] P;
    wire [7:0]  op_mode = {subtract, 7'b0001111};
    wire [17:0] a = {18{1'b0}};
    wire [17:0] b = {{2{sign & B_High[15]}}, B_High};
    wire [47:0] c = {{32{sign & A_High[15]}}, A_High};
    wire [17:0] d = {18{1'b0}};

    assign S = P[16:0];

    // DSP48A1: 48-bit Multi-Functional Arithmetic Block
    //          Spartan-6
    // Xilinx HDL Language Template, version 14.7
    DSP48A1 #(
        .A0REG(1),              // First stage A input pipeline register (0/1)
        .A1REG(0),              // Second stage A input pipeline register (0/1)
        .B0REG(1),              // First stage B input pipeline register (0/1)
        .B1REG(0),              // Second stage B input pipeline register (0/1)
        .CARRYINREG(0),         // CARRYIN input pipeline register (0/1)
        .CARRYINSEL("CARRYIN"), // Specify carry-in source, "CARRYIN" or "OPMODE5"
        .CARRYOUTREG(0),        // CARRYOUT output pipeline register (0/1)
        .CREG(1),               // C input pipeline register (0/1)
        .DREG(1),               // D pre-adder input pipeline register (0/1)
        .MREG(0),               // M pipeline register (0/1)
        .OPMODEREG(1),          // Enable=1/disable=0 OPMODE input pipeline registers
        .PREG(1),               // P output pipeline register (0/1)
        .RSTTYPE("SYNC")        // Specify reset type, "SYNC" or "ASYNC"
        )
        DSP48A1_BLAL (
        // Cascade Ports: 18-bit (each) output: Ports to cascade from one DSP48 to another
        .BCOUT(),                // 18-bit output: B port cascade output
        .PCOUT(),                // 48-bit output: P cascade output (if used, connect to PCIN of another DSP48A1)
        // Data Ports: 1-bit (each) output: Data input and output ports
        .CARRYOUT(),             // 1-bit output: carry output (if used, connect to CARRYIN pin of another DSP48A1)
        .CARRYOUTF(),            // 1-bit output: fabric carry output
        .M(),                    // 36-bit output: fabric multiplier data output
        .P(P),                   // 48-bit output: data output
        // Cascade Ports: 48-bit (each) input: Ports to cascade from one DSP48 to another
        .PCIN(),                 // 48-bit input: P cascade input (if used, connect to PCOUT of another DSP48A1)
        // Control Input Ports: 1-bit (each) input: Clocking and operation mode
        .CLK(clock),             // 1-bit input: clock input
        .OPMODE(op_mode),        // 8-bit input: operation mode input
        // Data Ports: 18-bit (each) input: Data input and output ports
        .A(a),                   // 18-bit input: A data input
        .B(b),                   // 18-bit input: B data input (connected to fabric or BCOUT of adjacent DSP48A1)
        .C(c),                   // 48-bit input: C data input
        .CARRYIN(CARRYIN),       // 1-bit input: carry input signal (if used, connect to CARRYOUT pin of another DSP48A1)
        .D(d),                   // 18-bit input: B pre-adder data input
        // Reset/Clock Enable Input Ports: 1-bit (each) input: Reset and enable input ports
        .CEA(1'b1),              // 1-bit input: active high clock enable input for A registers
        .CEB(CEB),               // 1-bit input: active high clock enable input for B registers
        .CEC(CEC),               // 1-bit input: active high clock enable input for C registers
        .CECARRYIN(1'b1),        // 1-bit input: active high clock enable input for CARRYIN registers
        .CED(1'b1),              // 1-bit input: active high clock enable input for D registers
        .CEM(1'b1),              // 1-bit input: active high clock enable input for multiplier registers
        .CEOPMODE(CEOPMODE),     // 1-bit input: active high clock enable input for OPMODE registers
        .CEP(CEP),               // 1-bit input: active high clock enable input for P registers
        .RSTA(1'b0),             // 1-bit input: reset input for A pipeline registers
        .RSTB(1'b0),             // 1-bit input: reset input for B pipeline registers
        .RSTC(1'b0),             // 1-bit input: reset input for C pipeline registers
        .RSTCARRYIN(1'b0),       // 1-bit input: reset input for CARRYIN pipeline registers
        .RSTD(1'b0),             // 1-bit input: reset input for D pipeline registers
        .RSTM(1'b0),             // 1-bit input: reset input for M pipeline registers
        .RSTOPMODE(1'b0),        // 1-bit input: reset input for OPMODE pipeline registers
        .RSTP(1'b0)              // 1-bit input: reset input for P pipeline registers
    );

endmodule

