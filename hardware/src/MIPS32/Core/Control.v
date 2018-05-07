`timescale 1ns / 1ps
/*
 * File         : Control.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The Datapath Controller. This module sets the datapath control
 *   bits for an incoming instruction. These control bits follow the
 *   instruction through each pipeline stage as needed, and constitute
 *   the effective operation of the processor through each pipeline stage.
 */
module Control(
    //--- Inputs ---
    input  [5:0] OpCode,
    input  [5:0] Funct,
    input  [4:0] Rs,            // Used to differentiate mfc0 and mtc0
    input  [4:0] Rt,            // Used to differentiate bgez,bgezal,bltz,bltzal,teqi,tgei,tgeiu,tlti,tltiu,tnei,cache
    input  [31:0] RsData,       // Read data 1 from Rs for branch conditions
    input  [31:0] RtData,       // Read data 2 from Rt for branch conditions
    //--- Direct Datapath ---
    output [1:0] PCSrc,         // Normal, Jumpi, Branch, or Jumpr
    output NextIsBDS,
    output reg BDSMask,         // A non-taken 'branch likely' masks the delay slot instruction
    output ALUSrcImm,
    output Movn,
    output Movz,
    output Trap,
    output TrapCond,
    output RegDst,
    output LLSC,
    output MemRead,
    output MemWrite,
    output MemHalf,
    output MemByte,
    output MemSignExtend,
    output RegWrite,
    output HiRead,
    output LoRead,
    output HiWrite,
    output LoWrite,
    output MemToReg,
    output reg [12:0] DP_Hazards,
    //--- Indirect Datapath ---
    output Left,
    output Right,
    output SignExtend,
    output Link,                // All branch/jump and link instructions
    output LinkReg,             // Jalr instruction which can specify its own Rd
    output reg [5:0] ALUOp,
    output XOP,                 // The instruction must be the only one in the pipeline
    //--- Special Instructions ---
    output Mfc0,
    output Mtc0,
    output Eret,
    output TLBp,
    output TLBr,
    output TLBwi,
    output TLBwr,
    output ICacheOp,
    output DCacheOp,
    output CP1,
    output CP2,
    output CP3,
    //--- Detected Exceptions ---
    output EXC_Bp,
    output EXC_Sys,
    output EXC_RI
    );

    `include "MIPS_Defines.v"


    // Local signals
    wire Branch, Branch_EQ, Branch_GTZ, Branch_LEZ, Branch_NEQ, Branch_GEZ, Branch_LTZ;
    wire CmpEQ, CmpGZ, CmpLZ, CmpGEZ, CmpLEZ;
    wire Sync;
    wire Movc;
    wire Unaligned_Mem;
    reg  [19:0] Datapath;


    // Assignments
    assign NextIsBDS     = Datapath[19] | Datapath[18];
    assign PCSrc[0]      = Datapath[18];
    assign ALUSrcImm     = Datapath[17];
    assign Movc          = Datapath[16];
    assign Trap          = Datapath[15];
    assign TrapCond      = Datapath[14];
    assign RegDst        = Datapath[13];
    assign LLSC          = Datapath[12];
    assign MemRead       = Datapath[11];
    assign MemWrite      = Datapath[10];
    assign MemHalf       = Datapath[9];
    assign MemByte       = Datapath[8];
    assign MemSignExtend = Datapath[7];
    assign RegWrite      = Datapath[6];
    wire   ControlWrite  = Datapath[5];
    assign MemToReg      = Datapath[4];
    assign HiRead        = Datapath[3];
    assign LoRead        = Datapath[2];
    assign HiWrite       = Datapath[1];
    assign LoWrite       = Datapath[0];

    // Set the main datapath control signals based on the Op Code
    always @(*) begin
        case (OpCode)
            // R-Type
            `Op_Type_R  :
                begin
                    case (Funct)
                        `Funct_Add     : Datapath <= `DP_Add;
                        `Funct_Addu    : Datapath <= `DP_Addu;
                        `Funct_And     : Datapath <= `DP_And;
                        `Funct_Break   : Datapath <= `DP_Break;
                        `Funct_Div     : Datapath <= `DP_Div;
                        `Funct_Divu    : Datapath <= `DP_Divu;
                        `Funct_Jalr    : Datapath <= `DP_Jalr;
                        `Funct_Jr      : Datapath <= `DP_Jr;
                        `Funct_Mfhi    : Datapath <= `DP_Mfhi;
                        `Funct_Mflo    : Datapath <= `DP_Mflo;
                        `Funct_Movn    : Datapath <= `DP_Movn;
                        `Funct_Movz    : Datapath <= `DP_Movz;
                        `Funct_Mthi    : Datapath <= `DP_Mthi;
                        `Funct_Mtlo    : Datapath <= `DP_Mtlo;
                        `Funct_Mult    : Datapath <= `DP_Mult;
                        `Funct_Multu   : Datapath <= `DP_Multu;
                        `Funct_Nor     : Datapath <= `DP_Nor;
                        `Funct_Or      : Datapath <= `DP_Or;
                        `Funct_Sll     : Datapath <= `DP_Sll;
                        `Funct_Sllv    : Datapath <= `DP_Sllv;
                        `Funct_Slt     : Datapath <= `DP_Slt;
                        `Funct_Sltu    : Datapath <= `DP_Sltu;
                        `Funct_Sra     : Datapath <= `DP_Sra;
                        `Funct_Srav    : Datapath <= `DP_Srav;
                        `Funct_Srl     : Datapath <= `DP_Srl;
                        `Funct_Srlv    : Datapath <= `DP_Srlv;
                        `Funct_Sub     : Datapath <= `DP_Sub;
                        `Funct_Subu    : Datapath <= `DP_Subu;
                        `Funct_Sync    : Datapath <= `DP_Sync;
                        `Funct_Syscall : Datapath <= `DP_Syscall;
                        `Funct_Teq     : Datapath <= `DP_Teq;
                        `Funct_Tge     : Datapath <= `DP_Tge;
                        `Funct_Tgeu    : Datapath <= `DP_Tgeu;
                        `Funct_Tlt     : Datapath <= `DP_Tlt;
                        `Funct_Tltu    : Datapath <= `DP_Tltu;
                        `Funct_Tne     : Datapath <= `DP_Tne;
                        `Funct_Xor     : Datapath <= `DP_Xor;
                        default        : Datapath <= `DP_None;
                    endcase
                end
            // R2-Type
            `Op_Type_R2 :
                begin
                    case (Funct)
                        `Funct_Clo   : Datapath <= `DP_Clo;
                        `Funct_Clz   : Datapath <= `DP_Clz;
                        `Funct_Madd  : Datapath <= `DP_Madd;
                        `Funct_Maddu : Datapath <= `DP_Maddu;
                        `Funct_Msub  : Datapath <= `DP_Msub;
                        `Funct_Msubu : Datapath <= `DP_Msubu;
                        `Funct_Mul   : Datapath <= `DP_Mul;
                        default      : Datapath <= `DP_None;
                    endcase
                end
            // I-Type
            `Op_Addi    : Datapath <= `DP_Addi;
            `Op_Addiu   : Datapath <= `DP_Addiu;
            `Op_Andi    : Datapath <= `DP_Andi;
            `Op_Ori     : Datapath <= `DP_Ori;
            `Op_Pref    : Datapath <= `DP_Pref;
            `Op_Slti    : Datapath <= `DP_Slti;
            `Op_Sltiu   : Datapath <= `DP_Sltiu;
            `Op_Xori    : Datapath <= `DP_Xori;
            // Jumps (using immediates)
            `Op_J       : Datapath <= `DP_J;
            `Op_Jal     : Datapath <= `DP_Jal;
            // Cache instruction
            `Op_Cache   : Datapath <= `DP_Cache;
            // Branches and Traps
            `Op_Type_BI :
                begin
                    case (Rt)
                        `OpRt_Bgez    : Datapath <= `DP_Bgez;
                        `OpRt_Bgezal  : Datapath <= `DP_Bgezal;
                        `OpRt_Bgezall : Datapath <= `DP_Bgezall;
                        `OpRt_Bgezl   : Datapath <= `DP_Bgezl;
                        `OpRt_Bltz    : Datapath <= `DP_Bltz;
                        `OpRt_Bltzal  : Datapath <= `DP_Bltzal;
                        `OpRt_Bltzall : Datapath <= `DP_Bltzall;
                        `OpRt_Bltzl   : Datapath <= `DP_Bltzl;
                        `OpRt_Teqi    : Datapath <= `DP_Teqi;
                        `OpRt_Tgei    : Datapath <= `DP_Tgei;
                        `OpRt_Tgeiu   : Datapath <= `DP_Tgeiu;
                        `OpRt_Tlti    : Datapath <= `DP_Tlti;
                        `OpRt_Tltiu   : Datapath <= `DP_Tltiu;
                        `OpRt_Tnei    : Datapath <= `DP_Tnei;
                        default       : Datapath <= `DP_None;
                    endcase
                end
            `Op_Beq     : Datapath <= `DP_Beq;
            `Op_Beql    : Datapath <= `DP_Beql;
            `Op_Bgtz    : Datapath <= `DP_Bgtz;
            `Op_Bgtzl   : Datapath <= `DP_Bgtzl;
            `Op_Blez    : Datapath <= `DP_Blez;
            `Op_Blezl   : Datapath <= `DP_Blezl;
            `Op_Bne     : Datapath <= `DP_Bne;
            `Op_Bnel    : Datapath <= `DP_Bnel;
            // Coprocessor 0
            `Op_Type_CP0 :
                begin
                    casex (Rs)
                        `OpRs_MF   : Datapath <= `DP_Mfc0;
                        `OpRs_MT   : Datapath <= `DP_Mtc0;
                        `OpRs_CO :
                            begin
                                case (Funct)
                                    `Funct_Eret  : Datapath <= `DP_Eret;
                                    `Funct_Tlbp  : Datapath <= `DP_Tlbp;
                                    `Funct_Tlbr  : Datapath <= `DP_Tlbr;
                                    `Funct_Tlbwi : Datapath <= `DP_Tlbwi;
                                    `Funct_Tlbwr : Datapath <= `DP_Tlbwr;
                                    default      : Datapath <= `DP_None;
                                endcase
                            end
                        default   : Datapath <= `DP_None;
                    endcase
                end
            // Memory
            `Op_Lb   : Datapath <= `DP_Lb;
            `Op_Lbu  : Datapath <= `DP_Lbu;
            `Op_Lh   : Datapath <= `DP_Lh;
            `Op_Lhu  : Datapath <= `DP_Lhu;
            `Op_Ll   : Datapath <= `DP_Ll;
            `Op_Lui  : Datapath <= `DP_Lui;
            `Op_Lw   : Datapath <= `DP_Lw;
            `Op_Lwl  : Datapath <= `DP_Lwl;
            `Op_Lwr  : Datapath <= `DP_Lwr;
            `Op_Sb   : Datapath <= `DP_Sb;
            `Op_Sc   : Datapath <= `DP_Sc;
            `Op_Sh   : Datapath <= `DP_Sh;
            `Op_Sw   : Datapath <= `DP_Sw;
            `Op_Swl  : Datapath <= `DP_Swl;
            `Op_Swr  : Datapath <= `DP_Swr;
            default  : Datapath <= `DP_None;
        endcase
    end

    // Set the Hazard Control Signals based on the Op Code
    always @(*) begin
        case (OpCode)
            // R-Type
            `Op_Type_R  :
                begin
                    case (Funct)
                        `Funct_Add     : DP_Hazards <= `HAZ_Add;
                        `Funct_Addu    : DP_Hazards <= `HAZ_Addu;
                        `Funct_And     : DP_Hazards <= `HAZ_And;
                        `Funct_Break   : DP_Hazards <= `HAZ_Break;
                        `Funct_Div     : DP_Hazards <= `HAZ_Div;
                        `Funct_Divu    : DP_Hazards <= `HAZ_Divu;
                        `Funct_Jalr    : DP_Hazards <= `HAZ_Jalr;
                        `Funct_Jr      : DP_Hazards <= `HAZ_Jr;
                        `Funct_Mfhi    : DP_Hazards <= `HAZ_Mfhi;
                        `Funct_Mflo    : DP_Hazards <= `HAZ_Mflo;
                        `Funct_Movn    : DP_Hazards <= `HAZ_Movn;
                        `Funct_Movz    : DP_Hazards <= `HAZ_Movz;
                        `Funct_Mthi    : DP_Hazards <= `HAZ_Mthi;
                        `Funct_Mtlo    : DP_Hazards <= `HAZ_Mtlo;
                        `Funct_Mult    : DP_Hazards <= `HAZ_Mult;
                        `Funct_Multu   : DP_Hazards <= `HAZ_Multu;
                        `Funct_Nor     : DP_Hazards <= `HAZ_Nor;
                        `Funct_Or      : DP_Hazards <= `HAZ_Or;
                        `Funct_Sll     : DP_Hazards <= `HAZ_Sll;
                        `Funct_Sllv    : DP_Hazards <= `HAZ_Sllv;
                        `Funct_Slt     : DP_Hazards <= `HAZ_Slt;
                        `Funct_Sltu    : DP_Hazards <= `HAZ_Sltu;
                        `Funct_Sra     : DP_Hazards <= `HAZ_Sra;
                        `Funct_Srav    : DP_Hazards <= `HAZ_Srav;
                        `Funct_Srl     : DP_Hazards <= `HAZ_Srl;
                        `Funct_Srlv    : DP_Hazards <= `HAZ_Srlv;
                        `Funct_Sub     : DP_Hazards <= `HAZ_Sub;
                        `Funct_Subu    : DP_Hazards <= `HAZ_Subu;
                        `Funct_Sync    : DP_Hazards <= `HAZ_Sync;
                        `Funct_Syscall : DP_Hazards <= `HAZ_Syscall;
                        `Funct_Teq     : DP_Hazards <= `HAZ_Teq;
                        `Funct_Tge     : DP_Hazards <= `HAZ_Tge;
                        `Funct_Tgeu    : DP_Hazards <= `HAZ_Tgeu;
                        `Funct_Tlt     : DP_Hazards <= `HAZ_Tlt;
                        `Funct_Tltu    : DP_Hazards <= `HAZ_Tltu;
                        `Funct_Tne     : DP_Hazards <= `HAZ_Tne;
                        `Funct_Xor     : DP_Hazards <= `HAZ_Xor;
                        default        : DP_Hazards <= `HAZ_DC;
                    endcase
                end
            // R2-Type
            `Op_Type_R2 :
                begin
                    case (Funct)
                        `Funct_Clo   : DP_Hazards <= `HAZ_Clo;
                        `Funct_Clz   : DP_Hazards <= `HAZ_Clz;
                        `Funct_Madd  : DP_Hazards <= `HAZ_Madd;
                        `Funct_Maddu : DP_Hazards <= `HAZ_Maddu;
                        `Funct_Msub  : DP_Hazards <= `HAZ_Msub;
                        `Funct_Msubu : DP_Hazards <= `HAZ_Msubu;
                        `Funct_Mul   : DP_Hazards <= `HAZ_Mul;
                        default      : DP_Hazards <= `HAZ_DC;
                    endcase
                end
            // I-Type
            `Op_Addi    : DP_Hazards <= `HAZ_Addi;
            `Op_Addiu   : DP_Hazards <= `HAZ_Addiu;
            `Op_Andi    : DP_Hazards <= `HAZ_Andi;
            `Op_Ori     : DP_Hazards <= `HAZ_Ori;
            `Op_Pref    : DP_Hazards <= `HAZ_Pref;
            `Op_Slti    : DP_Hazards <= `HAZ_Slti;
            `Op_Sltiu   : DP_Hazards <= `HAZ_Sltiu;
            `Op_Xori    : DP_Hazards <= `HAZ_Xori;
            // Jumps
            `Op_J       : DP_Hazards <= `HAZ_J;
            `Op_Jal     : DP_Hazards <= `HAZ_Jal;
            // Cache
            `Op_Cache   : DP_Hazards <= `HAZ_Cache;
            // Branches and Traps
            `Op_Type_BI :
                begin
                    case (Rt)
                        `OpRt_Bgez    : DP_Hazards <= `HAZ_Bgez;
                        `OpRt_Bgezal  : DP_Hazards <= `HAZ_Bgezal;
                        `OpRt_Bgezall : DP_Hazards <= `HAZ_Bgezall;
                        `OpRt_Bgezl   : DP_Hazards <= `HAZ_Bgezl;
                        `OpRt_Bltz    : DP_Hazards <= `HAZ_Bltz;
                        `OpRt_Bltzal  : DP_Hazards <= `HAZ_Bltzal;
                        `OpRt_Bltzall : DP_Hazards <= `HAZ_Bltzall;
                        `OpRt_Bltzl   : DP_Hazards <= `HAZ_Bltzl;
                        `OpRt_Teqi    : DP_Hazards <= `HAZ_Teqi;
                        `OpRt_Tgei    : DP_Hazards <= `HAZ_Tgei;
                        `OpRt_Tgeiu   : DP_Hazards <= `HAZ_Tgeiu;
                        `OpRt_Tlti    : DP_Hazards <= `HAZ_Tlti;
                        `OpRt_Tltiu   : DP_Hazards <= `HAZ_Tltiu;
                        `OpRt_Tnei    : DP_Hazards <= `HAZ_Tnei;
                        default       : DP_Hazards <= `HAZ_DC;
                    endcase
                end
            `Op_Beq     : DP_Hazards <= `HAZ_Beq;
            `Op_Beql    : DP_Hazards <= `HAZ_Beql;
            `Op_Bgtz    : DP_Hazards <= `HAZ_Bgtz;
            `Op_Bgtzl   : DP_Hazards <= `HAZ_Bgtzl;
            `Op_Blez    : DP_Hazards <= `HAZ_Blez;
            `Op_Blezl   : DP_Hazards <= `HAZ_Blezl;
            `Op_Bne     : DP_Hazards <= `HAZ_Bne;
            `Op_Bnel    : DP_Hazards <= `HAZ_Bnel;
            // Coprocessor 0
            `Op_Type_CP0 :
                begin
                    casex (Rs)
                        `OpRs_MF   : DP_Hazards <= `HAZ_Mfc0;
                        `OpRs_MT   : DP_Hazards <= `HAZ_Mtc0;
                        `OpRs_CO:
                            begin
                                case (Funct)
                                    `Funct_Eret  : DP_Hazards <= `HAZ_Eret;
                                    `Funct_Tlbp  : DP_Hazards <= `HAZ_Tlbp;
                                    `Funct_Tlbr  : DP_Hazards <= `HAZ_Tlbr;
                                    `Funct_Tlbwi : DP_Hazards <= `HAZ_Tlbwi;
                                    `Funct_Tlbwr : DP_Hazards <= `HAZ_Tlbwr;
                                    default      : DP_Hazards <= `HAZ_DC;
                                endcase
                            end
                        default   : DP_Hazards <= `HAZ_DC;
                    endcase
                end
            // Memory
            `Op_Lb   : DP_Hazards <= `HAZ_Lb;
            `Op_Lbu  : DP_Hazards <= `HAZ_Lbu;
            `Op_Lh   : DP_Hazards <= `HAZ_Lh;
            `Op_Lhu  : DP_Hazards <= `HAZ_Lhu;
            `Op_Ll   : DP_Hazards <= `HAZ_Ll;
            `Op_Lui  : DP_Hazards <= `HAZ_Lui;
            `Op_Lw   : DP_Hazards <= `HAZ_Lw;
            `Op_Lwl  : DP_Hazards <= `HAZ_Lwl;
            `Op_Lwr  : DP_Hazards <= `HAZ_Lwr;
            `Op_Sb   : DP_Hazards <= `HAZ_Sb;
            `Op_Sc   : DP_Hazards <= `HAZ_Sc;
            `Op_Sh   : DP_Hazards <= `HAZ_Sh;
            `Op_Sw   : DP_Hazards <= `HAZ_Sw;
            `Op_Swl  : DP_Hazards <= `HAZ_Swl;
            `Op_Swr  : DP_Hazards <= `HAZ_Swr;
            default  : DP_Hazards <= `HAZ_DC;
        endcase
    end

    // ALU Assignment
    always @(*) begin
        case (OpCode)
            `Op_Type_R  :
                begin
                    case (Funct)
                        `Funct_Add     : ALUOp <= `AluOp_Add;
                        `Funct_Addu    : ALUOp <= `AluOp_Addu;
                        `Funct_And     : ALUOp <= `AluOp_And;
                        `Funct_Div     : ALUOp <= `AluOp_Div;
                        `Funct_Divu    : ALUOp <= `AluOp_Divu;
                        `Funct_Jalr    : ALUOp <= `AluOp_Addu;
                        `Funct_Mfhi    : ALUOp <= `AluOp_Mfhi;
                        `Funct_Mflo    : ALUOp <= `AluOp_Mflo;
                        `Funct_Movn    : ALUOp <= `AluOp_PassA;
                        `Funct_Movz    : ALUOp <= `AluOp_PassA;
                        `Funct_Mthi    : ALUOp <= `AluOp_PassA;
                        `Funct_Mtlo    : ALUOp <= `AluOp_PassA;
                        `Funct_Mult    : ALUOp <= `AluOp_Mult;
                        `Funct_Multu   : ALUOp <= `AluOp_Multu;
                        `Funct_Nor     : ALUOp <= `AluOp_Nor;
                        `Funct_Or      : ALUOp <= `AluOp_Or;
                        `Funct_Sll     : ALUOp <= `AluOp_Sll;
                        `Funct_Sllv    : ALUOp <= `AluOp_Sllv;
                        `Funct_Slt     : ALUOp <= `AluOp_Slt;
                        `Funct_Sltu    : ALUOp <= `AluOp_Sltu;
                        `Funct_Sra     : ALUOp <= `AluOp_Sra;
                        `Funct_Srav    : ALUOp <= `AluOp_Srav;
                        `Funct_Srl     : ALUOp <= `AluOp_Srl;
                        `Funct_Srlv    : ALUOp <= `AluOp_Srlv;
                        `Funct_Sub     : ALUOp <= `AluOp_Sub;
                        `Funct_Subu    : ALUOp <= `AluOp_Subu;
                        `Funct_Sync    : ALUOp <= `AluOp_Addu;
                        `Funct_Syscall : ALUOp <= `AluOp_Addu;
                        `Funct_Teq     : ALUOp <= `AluOp_Subu;
                        `Funct_Tge     : ALUOp <= `AluOp_Slt;
                        `Funct_Tgeu    : ALUOp <= `AluOp_Sltu;
                        `Funct_Tlt     : ALUOp <= `AluOp_Slt;
                        `Funct_Tltu    : ALUOp <= `AluOp_Sltu;
                        `Funct_Tne     : ALUOp <= `AluOp_Subu;
                        `Funct_Xor     : ALUOp <= `AluOp_Xor;
                        default        : ALUOp <= `AluOp_Addu;
                    endcase
                end
            `Op_Type_R2 :
                begin
                    case (Funct)
                        `Funct_Clo   : ALUOp <= `AluOp_Clo;
                        `Funct_Clz   : ALUOp <= `AluOp_Clz;
                        `Funct_Madd  : ALUOp <= `AluOp_Madd;
                        `Funct_Maddu : ALUOp <= `AluOp_Maddu;
                        `Funct_Msub  : ALUOp <= `AluOp_Msub;
                        `Funct_Msubu : ALUOp <= `AluOp_Msubu;
                        `Funct_Mul   : ALUOp <= `AluOp_Mul;
                        default      : ALUOp <= `AluOp_Addu;
                    endcase
                end
            `Op_Type_BI  :
                begin
                    case (Rt)
                        `OpRt_Teqi   : ALUOp <= `AluOp_Subu;
                        `OpRt_Tgei   : ALUOp <= `AluOp_Slt;
                        `OpRt_Tgeiu  : ALUOp <= `AluOp_Sltu;
                        `OpRt_Tlti   : ALUOp <= `AluOp_Slt;
                        `OpRt_Tltiu  : ALUOp <= `AluOp_Sltu;
                        `OpRt_Tnei   : ALUOp <= `AluOp_Subu;
                        default      : ALUOp <= `AluOp_Addu;  // Branches don't matter.
                    endcase
                end
            `Op_Type_CP0 :
                begin
                    case (Rs)
                        `OpRs_MF     : ALUOp <= `AluOp_PassA;
                        `OpRs_MT     : ALUOp <= `AluOp_PassB;
                        default      : ALUOp <= `AluOp_Addu;    // Don't care
                    endcase
                end
            `Op_Cache    : ALUOp <= `AluOp_Addu;
            `Op_Addi     : ALUOp <= `AluOp_Add;
            `Op_Addiu    : ALUOp <= `AluOp_Addu;
            `Op_Andi     : ALUOp <= `AluOp_And;
            `Op_Jal      : ALUOp <= `AluOp_Addu;
            `Op_Lb       : ALUOp <= `AluOp_Addu;
            `Op_Lbu      : ALUOp <= `AluOp_Addu;
            `Op_Lh       : ALUOp <= `AluOp_Addu;
            `Op_Lhu      : ALUOp <= `AluOp_Addu;
            `Op_Ll       : ALUOp <= `AluOp_Addu;
            `Op_Lui      : ALUOp <= `AluOp_Lui;
            `Op_Lw       : ALUOp <= `AluOp_Addu;
            `Op_Lwl      : ALUOp <= `AluOp_Addu;
            `Op_Lwr      : ALUOp <= `AluOp_Addu;
            `Op_Ori      : ALUOp <= `AluOp_Or;
            `Op_Sb       : ALUOp <= `AluOp_Addu;
            `Op_Sc       : ALUOp <= `AluOp_Addu;
            `Op_Sh       : ALUOp <= `AluOp_Addu;
            `Op_Slti     : ALUOp <= `AluOp_Slt;
            `Op_Sltiu    : ALUOp <= `AluOp_Sltu;
            `Op_Sw       : ALUOp <= `AluOp_Addu;
            `Op_Swl      : ALUOp <= `AluOp_Addu;
            `Op_Swr      : ALUOp <= `AluOp_Addu;
            `Op_Xori     : ALUOp <= `AluOp_Xor;
            default      : ALUOp <= `AluOp_Addu;
        endcase
    end


    /***
     These remaining options cover portions of the datapath that are not
     controlled directly by the datapath bits. Note that some refer to bits of
     the opcode or other fields, which breaks the otherwise fully-abstracted view
     of instruction encodings. Make sure when adding custom instructions that
     no false positives/negatives are generated here.
     ***/

    // Branch Detection: Options are mutually exclusive.
    assign Branch_EQ  =  OpCode[2] & ~OpCode[1] & ~OpCode[0] &  CmpEQ;
    assign Branch_GTZ =  OpCode[2] &  OpCode[1] &  OpCode[0] &  CmpGZ;
    assign Branch_LEZ =  OpCode[2] &  OpCode[1] & ~OpCode[0] &  CmpLEZ;
    assign Branch_NEQ =  OpCode[2] & ~OpCode[1] &  OpCode[0] & ~CmpEQ;
    assign Branch_GEZ = ~OpCode[2] &  Rt[0] & CmpGEZ;
    assign Branch_LTZ = ~OpCode[2] & ~Rt[0] & CmpLZ;

    assign Branch = |{Branch_EQ, Branch_GTZ, Branch_LEZ, Branch_NEQ, Branch_GEZ, Branch_LTZ};
    assign PCSrc[1] = (Datapath[19] & ~Datapath[18]) ? Branch : Datapath[19];

    // Branch/Jump linking is detected when these instructions write to the register file
    assign Link    = (Datapath[19] | Datapath[18]) & Datapath[6];
    assign LinkReg = (Datapath[19] & Datapath[18]) & Datapath[6];

    // Branch likely instructions conditionally mask the delay slot instruction
    always @(*) begin
        case (OpCode)
            `Op_Type_BI:
                begin
                    case (Rt)
                        `OpRt_Bgezall : BDSMask = ~CmpGEZ;
                        `OpRt_Bgezl   : BDSMask = ~CmpGEZ;
                        `OpRt_Bltzall : BDSMask = ~CmpLZ;
                        `OpRt_Bltzl   : BDSMask = ~CmpLZ;
                        default       : BDSMask = 1'b0;
                    endcase
                end
            `Op_Beql    : BDSMask = ~CmpEQ;
            `Op_Bgtzl   : BDSMask = ~CmpGZ;
            `Op_Blezl   : BDSMask = ~CmpLEZ;
            `Op_Bnel    : BDSMask = CmpEQ;
            default     : BDSMask = 1'b0;
        endcase
    end

    // Sign- or Zero-Extension Control. The only ops that require zero-extension are
    // Andi, Ori, and Xori. The following also zero-extends 'lui', however it does not alter the effect of lui.
    assign SignExtend = (OpCode[5:2] != 4'b0011);

    // Move Conditional
    assign Movn = Movc &  Funct[0];
    assign Movz = Movc & ~Funct[0];

    /* Cache Implementation Notes:
     *   - Primary I/D caches are supported. The infrastructure is almost completely here for S/T caches.
     *   - Supported I-cache instructions: Index Invalidate (000), Index Store Tag (010), Address Hit Invalidate (100).
     *   - Supported D-cache instructions: Index Writeback Invalidate (000), Index Store Tag (010),
     *     Address Hit Writeback Invalidate (101), Address Hit Writeback (110).
     */

    // Coprocessor 0 (Mfc0, Mtc0, ERET, TLB, Cache) control signals.
    assign Mfc0     = ((OpCode == `Op_Mfc0)  & (Rs == `OpRs_MF));
    assign Mtc0     = ((OpCode == `Op_Mtc0)  & (Rs == `OpRs_MT));
    assign Eret     = ((OpCode == `Op_Eret)  & (Rs[4] == `OpRs_CO4) & (Funct == `Funct_Eret));
    assign TLBp     = ((OpCode == `Op_Tlbp)  & (Rs[4] == `OpRs_CO4) & (Funct == `Funct_Tlbp));
    assign TLBr     = ((OpCode == `Op_Tlbr)  & (Rs[4] == `OpRs_CO4) & (Funct == `Funct_Tlbr));
    assign TLBwi    = ((OpCode == `Op_Tlbwi) & (Rs[4] == `OpRs_CO4) & (Funct == `Funct_Tlbwi));
    assign TLBwr    = ((OpCode == `Op_Tlbwr) & (Rs[4] == `OpRs_CO4) & (Funct == `Funct_Tlbwr));
    assign ICacheOp = (OpCode == `Op_Cache) & ~Rt[0];
    assign DCacheOp = (OpCode == `Op_Cache) &  Rt[0];

    // Coprocessor 1,2,3 accesses (not implemented)
    assign CP1 = (OpCode == `Op_Type_CP1);
    assign CP2 = (OpCode == `Op_Type_CP2);
    assign CP3 = (OpCode == `Op_Type_CP3);

    // Exceptions found in ID
    assign EXC_Sys = ((OpCode == `Op_Type_R) & (Funct == `Funct_Syscall));
    assign EXC_Bp  = ((OpCode == `Op_Type_R) & (Funct == `Funct_Break));

    // Unaligned Memory Accesses (lwl, lwr, swl, swr)
    assign Unaligned_Mem = OpCode[5] & ~OpCode[4] & OpCode[1] & ~OpCode[0];
    assign Left  = Unaligned_Mem & ~OpCode[2];
    assign Right = Unaligned_Mem &  OpCode[2];

    // Sync instruction (note that Rs/Rt/Rd should be 0s but we currently don't care)
    assign Sync = (OpCode == `Op_Sync) & (Funct == `Funct_Sync);

    // 'eXclusive OPerations' (serialized instructions) do not allow other instructions behind them in the pipeline.
    // This signal covers the following instructions: mtc0, eret, cache, sync, tlbp, tlbr, tlbwi, tlbwr.
    assign XOP = ControlWrite | Sync | (OpCode == `Op_Cache);

    // TODO: Reserved Instruction Exception must still be implemented
    assign EXC_RI  = 1'b0;


    /*** Condition Compare Unit ***/
    Compare Compare (
        .A    (RsData),
        .B    (RtData),
        .EQ   (CmpEQ),
        .GZ   (CmpGZ),
        .LZ   (CmpLZ),
        .GEZ  (CmpGEZ),
        .LEZ  (CmpLEZ)
    );

endmodule

