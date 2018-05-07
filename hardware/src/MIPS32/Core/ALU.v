`timescale 1ns / 1ps
/*
 * File         : ALU.v
 * Project      : MIPS32 Mux
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   An Arithmetic Logic Unit for a MIPS32 processor.
 */
module ALU(
    input             clock,
    input             reset,
    input             X1_Issued,
    input             X1_HiLoWrite,
    input      [31:0] A,
    input      [31:0] B,
    input      [5:0]  Operation,
    input      [4:0]  Shamt,
    input      [31:0] HiIn,
    input      [31:0] LoIn,
    input             HiWrite,
    input             LoWrite,
    output reg [31:0] Result,
    output reg        EXC_Ov,
    output            BZero,        // Used for movc
    output            ALU_Busy,
    output     [63:0] Mult_Out,
    output     [31:0] Div_QOut,
    output     [31:0] Div_ROut
    );

    `include "MIPS_Defines.v"

    wire signed [4:0] Shamts = Shamt;
    wire signed [31:0] As = A;
    wire signed [31:0] Bs = B;
    reg [5:0] CLO_Result, CLZ_Result;
    assign BZero = ~|{B};

    // Multiply, divide, and fused operation signals
    wire [31:0] Hi_out;
    wire [31:0] Lo_out;
    wire [63:0] HiLo = {Hi_out, Lo_out};
    reg         sign;
    reg         fused;
    reg         subtract;
    wire        mult_busy;
    wire        mult_start = X1_Issued & X1_HiLoWrite & (Operation != `AluOp_Div) & (Operation != `AluOp_Divu);
    wire [64:0] mult_output;

    // Multi-cycle Hardware Divider
    wire [31:0] quotient_out;
    wire [31:0] remainder_out;
    wire        div_start  = X1_Issued & X1_HiLoWrite & (Operation == `AluOp_Div);
    wire        divu_start = X1_Issued & X1_HiLoWrite & (Operation == `AluOp_Divu);
    wire        div_busy;

    always @(*) begin
        case (Operation)
            `AluOp_Add      : Result <= A + B;
            `AluOp_Addu     : Result <= A + B;
            `AluOp_And      : Result <= A & B;
            `AluOp_Clo      : Result <= {{26{1'b0}}, CLO_Result};
            `AluOp_Clz      : Result <= {{26{1'b0}}, CLZ_Result};
            `AluOp_Mfhi     : Result <= Hi_out;
            `AluOp_Mflo     : Result <= Lo_out;
            `AluOp_Nor      : Result <= ~(A | B);
            `AluOp_Or       : Result <= A | B;
            `AluOp_Sll      : Result <= B << Shamts;
            `AluOp_Lui      : Result <= {B[15:0], {16{1'b0}}};
            `AluOp_Sllv     : Result <= B << A[4:0];
            `AluOp_Slt      : Result <= (As < Bs) ? 32'd1 : 32'd0;
            `AluOp_Sltu     : Result <= (A  < B)  ? 32'd1 : 32'd0;
            `AluOp_Sra      : Result <= Bs >>> Shamts;
            `AluOp_Srav     : Result <= Bs >>> As[4:0];
            `AluOp_Srl      : Result <= B >> Shamts;
            `AluOp_Srlv     : Result <= B >> A[4:0];
            `AluOp_Sub      : Result <= A - B;
            `AluOp_Subu     : Result <= A - B;
            `AluOp_Xor      : Result <= A ^ B;
            `AluOp_PassA    : Result <= A;
            `AluOp_PassB    : Result <= B;
            default         : Result <= {32{1'bx}};
        endcase
    end

    // Detect overflow for signed addition/subtraction operations.
    always @(*) begin
        case (Operation)
            `AluOp_Add : EXC_Ov <= ((A[31] ~^ B[31]) & (A[31] ^ Result[31]));
            `AluOp_Sub : EXC_Ov <= ((A[31]  ^ B[31]) & (A[31] ^ Result[31]));
            default    : EXC_Ov <= 1'b0;
        endcase
    end

    // Count Leading Ones
    always @(A) begin
        casex (A)
            32'b0xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd0;
            32'b10xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd1;
            32'b110x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd2;
            32'b1110_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd3;
            32'b1111_0xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd4;
            32'b1111_10xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd5;
            32'b1111_110x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd6;
            32'b1111_1110_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd7;
            32'b1111_1111_0xxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd8;
            32'b1111_1111_10xx_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd9;
            32'b1111_1111_110x_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd10;
            32'b1111_1111_1110_xxxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd11;
            32'b1111_1111_1111_0xxx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd12;
            32'b1111_1111_1111_10xx_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd13;
            32'b1111_1111_1111_110x_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd14;
            32'b1111_1111_1111_1110_xxxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd15;
            32'b1111_1111_1111_1111_0xxx_xxxx_xxxx_xxxx : CLO_Result <= 6'd16;
            32'b1111_1111_1111_1111_10xx_xxxx_xxxx_xxxx : CLO_Result <= 6'd17;
            32'b1111_1111_1111_1111_110x_xxxx_xxxx_xxxx : CLO_Result <= 6'd18;
            32'b1111_1111_1111_1111_1110_xxxx_xxxx_xxxx : CLO_Result <= 6'd19;
            32'b1111_1111_1111_1111_1111_0xxx_xxxx_xxxx : CLO_Result <= 6'd20;
            32'b1111_1111_1111_1111_1111_10xx_xxxx_xxxx : CLO_Result <= 6'd21;
            32'b1111_1111_1111_1111_1111_110x_xxxx_xxxx : CLO_Result <= 6'd22;
            32'b1111_1111_1111_1111_1111_1110_xxxx_xxxx : CLO_Result <= 6'd23;
            32'b1111_1111_1111_1111_1111_1111_0xxx_xxxx : CLO_Result <= 6'd24;
            32'b1111_1111_1111_1111_1111_1111_10xx_xxxx : CLO_Result <= 6'd25;
            32'b1111_1111_1111_1111_1111_1111_110x_xxxx : CLO_Result <= 6'd26;
            32'b1111_1111_1111_1111_1111_1111_1110_xxxx : CLO_Result <= 6'd27;
            32'b1111_1111_1111_1111_1111_1111_1111_0xxx : CLO_Result <= 6'd28;
            32'b1111_1111_1111_1111_1111_1111_1111_10xx : CLO_Result <= 6'd29;
            32'b1111_1111_1111_1111_1111_1111_1111_110x : CLO_Result <= 6'd30;
            32'b1111_1111_1111_1111_1111_1111_1111_1110 : CLO_Result <= 6'd31;
            32'b1111_1111_1111_1111_1111_1111_1111_1111 : CLO_Result <= 6'd32;
            default : CLO_Result <= 6'd0;
        endcase
    end

    // Count Leading Zeros
    always @(A) begin
        casex (A)
            32'b1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd0;
            32'b01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd1;
            32'b001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd2;
            32'b0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd3;
            32'b0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd4;
            32'b0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd5;
            32'b0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd6;
            32'b0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd7;
            32'b0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd8;
            32'b0000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd9;
            32'b0000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd10;
            32'b0000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd11;
            32'b0000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd12;
            32'b0000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd13;
            32'b0000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd14;
            32'b0000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd15;
            32'b0000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd16;
            32'b0000_0000_0000_0000_01xx_xxxx_xxxx_xxxx : CLZ_Result <= 6'd17;
            32'b0000_0000_0000_0000_001x_xxxx_xxxx_xxxx : CLZ_Result <= 6'd18;
            32'b0000_0000_0000_0000_0001_xxxx_xxxx_xxxx : CLZ_Result <= 6'd19;
            32'b0000_0000_0000_0000_0000_1xxx_xxxx_xxxx : CLZ_Result <= 6'd20;
            32'b0000_0000_0000_0000_0000_01xx_xxxx_xxxx : CLZ_Result <= 6'd21;
            32'b0000_0000_0000_0000_0000_001x_xxxx_xxxx : CLZ_Result <= 6'd22;
            32'b0000_0000_0000_0000_0000_0001_xxxx_xxxx : CLZ_Result <= 6'd23;
            32'b0000_0000_0000_0000_0000_0000_1xxx_xxxx : CLZ_Result <= 6'd24;
            32'b0000_0000_0000_0000_0000_0000_01xx_xxxx : CLZ_Result <= 6'd25;
            32'b0000_0000_0000_0000_0000_0000_001x_xxxx : CLZ_Result <= 6'd26;
            32'b0000_0000_0000_0000_0000_0000_0001_xxxx : CLZ_Result <= 6'd27;
            32'b0000_0000_0000_0000_0000_0000_0000_1xxx : CLZ_Result <= 6'd28;
            32'b0000_0000_0000_0000_0000_0000_0000_01xx : CLZ_Result <= 6'd29;
            32'b0000_0000_0000_0000_0000_0000_0000_001x : CLZ_Result <= 6'd30;
            32'b0000_0000_0000_0000_0000_0000_0000_0001 : CLZ_Result <= 6'd31;
            32'b0000_0000_0000_0000_0000_0000_0000_0000 : CLZ_Result <= 6'd32;
            default : CLZ_Result <= 6'd0;
        endcase
    end

    always @(*) begin
        case (Operation)
            `AluOp_Divu  : sign <= 1'b0;
            `AluOp_Maddu : sign <= 1'b0;
            `AluOp_Msubu : sign <= 1'b0;
            `AluOp_Multu : sign <= 1'b0;
            default      : sign <= 1'b1;
        endcase
    end

    always @(*) begin
        case (Operation)
            `AluOp_Madd  : fused <= 1'b1;
            `AluOp_Maddu : fused <= 1'b1;
            `AluOp_Msub  : fused <= 1'b1;
            `AluOp_Msubu : fused <= 1'b1;
            default      : fused <= 1'b0;
        endcase
    end

    always @(*) begin
        case (Operation)
            `AluOp_Msub  : subtract <= 1'b1;
            `AluOp_Msubu : subtract <= 1'b1;
            default      : subtract <= 1'b0;
        endcase
    end

    // HI/LO ISA Registers
    DFF_E #(.WIDTH(32)) HI (.clock(clock), .enable(HiWrite), .D(HiIn), .Q(Hi_out));
    DFF_E #(.WIDTH(32)) LO (.clock(clock), .enable(LoWrite), .D(LoIn), .Q(Lo_out));

    // Xilinx-specific DSP48A-based Muliplier / Fused Multiply-Add/Sub
    DSP_MAddSub_32x32x64 MultAddSub (
        .clock    (clock),
        .reset    (reset),
        .A        (A),
        .B        (B),
        .C        (HiLo),       // need to be held steady?
        .sign     (sign),
        .fused    (fused),
        .subtract (subtract),
        .start    (mult_start),
        .busy     (mult_busy),
        .D        (mult_output)   // XXX figure out MSB that isn't needed
    );

    Divide Divider (
        .clock      (clock),
        .reset      (reset),
        .OP_div     (div_start),
        .OP_divu    (divu_start),
        .Dividend   (A),
        .Divisor    (B),
        .Quotient   (quotient_out),
        .Remainder  (remainder_out),
        .Stall      (div_busy)
    );

    assign ALU_Busy = mult_busy | div_busy;
    assign Mult_Out = mult_output[63:0];
    assign Div_QOut = quotient_out;
    assign Div_ROut = remainder_out;

endmodule

