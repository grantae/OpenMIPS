/*
 * File         : MIPS_Defines.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Provides a language abstraction for the MIPS32-specific op-codes and
 *   the processor-specific datapath, hazard, and exception bits which
 *   control the processor. These names are used extensively
 *   throughout the processor HDL modules.
 */

/*** Physical Address Bits

     12 < PABITS <= 36. (e.g., 26 bits -> 64 MB physical RAM)

     Supply this parameter to the top-level module (Processor.v or MIPS32.v)
*/

/*** Exception Vector Locations ***

     When the CPU powers up or is reset, it will begin execution at '`EXC_Vector_Base_Reset'.
     All other exceptions are the sum of a base address and offset:
      - The base address is either a bootstrap or normal value. It is controlled by
        the 'BEV' bit in the CP0 'Status' register. Both base addresses can be mapped to
        the same location.
      - The offset address is either a standard offset (which is always used for
        non-interrupt general exceptions in this processor because it lacks TLB Refill
        and Cache errors), or a special interrupt-only offset for interrupts, which is
        enabled with the 'IV' bit in the CP0 'Cause' register.

     Current Setup:
        General exceptions go to 0x0. Interrupts go to 0x8. Booting starts at 0x10.
*/
`define EXC_Vector_Reset               32'hBFC0_0000    // Reset, Soft Reset, NMI
`define EXC_Vector_Base_Cache_Boot     32'hBFC0_0200    // Cache Error
`define EXC_Vector_Base_General_Boot   32'hBFC0_0200    // General
`define EXC_Vector_Base_Cache_NoBoot   32'hA000_0000    // Cache Error
`define EXC_Vector_Base_General_NoBoot 32'h8000_0000    // General
`define EXC_Vector_Offset_None         32'h0000_0000    // Reset, Soft Reset, NMI, TLB Refill (~EXL)
`define EXC_Vector_Offset_Cache        32'h0000_0100    // Cache Error
`define EXC_Vector_Offset_General      32'h0000_0180    // General
`define EXC_Vector_Offset_Interrupt    32'h0000_0200    // Interruptdard is 0x0000_0200


/*** Processor Endianness ***

     The MIPS Configuration Register (CP0 Register 16 Select 0) specifies the processor's
     endianness. A processor in user mode may switch to reverse endianness, which would be
     the opposite of this bit.
*/
`define Big_Endian 1'b0



/*** Encodings for MIPS32 Release 1 Architecture ***/


/* Op Code Categories */
`define Op_Type_R   6'b00_0000  // Standard R-Type instructions
`define Op_Type_R2  6'b01_1100  // Extended R-Like instructions
`define Op_Type_BI  6'b00_0001  // Branch/Trap extended instructions
`define Op_Type_CP0 6'b01_0000  // Coprocessor 0 instructions
`define Op_Type_CP1 6'b01_0001  // Coprocessor 1 instructions (not implemented)
`define Op_Type_CP2 6'b01_0010  // Coprocessor 2 instructions (not implemented)
`define Op_Type_CP3 6'b01_0011  // Coprocessor 3 instructions (not implemented)
// --------------------------------------
`define Op_Add      `Op_Type_R
`define Op_Addi     6'b00_1000
`define Op_Addiu    6'b00_1001
`define Op_Addu     `Op_Type_R
`define Op_And      `Op_Type_R
`define Op_Andi     6'b00_1100
`define Op_Beq      6'b00_0100
`define Op_Beql     6'b01_0100
`define Op_Bgez     `Op_Type_BI
`define Op_Bgezal   `Op_Type_BI
`define Op_Bgezall  `Op_Type_BI
`define Op_Bgezl    `Op_Type_BI
`define Op_Bgtz     6'b00_0111
`define Op_Bgtzl    6'b01_0111
`define Op_Blez     6'b00_0110
`define Op_Blezl    6'b01_0110
`define Op_Bltz     `Op_Type_BI
`define Op_Bltzal   `Op_Type_BI
`define Op_Bltzall  `Op_Type_BI
`define Op_Bltzl    `Op_Type_BI
`define Op_Bne      6'b00_0101
`define Op_Bnel     6'b01_0101
`define Op_Break    `Op_Type_R
`define Op_Cache    6'b10_1111
`define Op_Clo      `Op_Type_R2
`define Op_Clz      `Op_Type_R2
`define Op_Div      `Op_Type_R
`define Op_Divu     `Op_Type_R
`define Op_Eret     `Op_Type_CP0
`define Op_J        6'b00_0010
`define Op_Jal      6'b00_0011
`define Op_Jalr     `Op_Type_R
`define Op_Jr       `Op_Type_R
`define Op_Lb       6'b10_0000
`define Op_Lbu      6'b10_0100
`define Op_Lh       6'b10_0001
`define Op_Lhu      6'b10_0101
`define Op_Ll       6'b11_0000
`define Op_Lui      6'b00_1111
`define Op_Lw       6'b10_0011
`define Op_Lwl      6'b10_0010
`define Op_Lwr      6'b10_0110
`define Op_Madd     `Op_Type_R2
`define Op_Maddu    `Op_Type_R2
`define Op_Mfc0     `Op_Type_CP0
`define Op_Mfhi     `Op_Type_R
`define Op_Mflo     `Op_Type_R
`define Op_Movn     `Op_Type_R      // XXX TODO this op may need reimplementation: Put Rs in ALU.a, Rt in ALU.b, use Bzero/PassA
`define Op_Movz     `Op_Type_Ri     // XXX TODO this op may need reimplementation
`define Op_Msub     `Op_Type_R2
`define Op_Msubu    `Op_Type_R2
`define Op_Mtc0     `Op_Type_CP0
`define Op_Mthi     `Op_Type_R
`define Op_Mtlo     `Op_Type_R
`define Op_Mul      `Op_Type_R2
`define Op_Mult     `Op_Type_R
`define Op_Multu    `Op_Type_R
`define Op_Nor      `Op_Type_R
`define Op_Or       `Op_Type_R
`define Op_Ori      6'b00_1101
`define Op_Pref     6'b11_0011 // Prefetch does nothing in this implementation.
`define Op_Sb       6'b10_1000
`define Op_Sc       6'b11_1000
`define Op_Sh       6'b10_1001
`define Op_Sll      `Op_Type_R
`define Op_Sllv     `Op_Type_R
`define Op_Slt      `Op_Type_R
`define Op_Slti     6'b00_1010
`define Op_Sltiu    6'b00_1011
`define Op_Sltu     `Op_Type_R
`define Op_Sra      `Op_Type_R
`define Op_Srav     `Op_Type_R
`define Op_Srl      `Op_Type_R
`define Op_Srlv     `Op_Type_R
`define Op_Sub      `Op_Type_R
`define Op_Subu     `Op_Type_R
`define Op_Sw       6'b10_1011
`define Op_Swl      6'b10_1010
`define Op_Swr      6'b10_1110
`define Op_Sync     `Op_Type_R
`define Op_Syscall  `Op_Type_R
`define Op_Teq      `Op_Type_R
`define Op_Teqi     `Op_Type_BI
`define Op_Tge      `Op_Type_R
`define Op_Tgei     `Op_Type_BI
`define Op_Tgeiu    `Op_Type_BI
`define Op_Tgeu     `Op_Type_R
`define Op_Tlbp     `Op_Type_CP0
`define Op_Tlbr     `Op_Type_CP0
`define Op_Tlbwi    `Op_Type_CP0
`define Op_Tlbwr    `Op_Type_CP0
`define Op_Tlt      `Op_Type_R
`define Op_Tlti     `Op_Type_BI
`define Op_Tltiu    `Op_Type_BI
`define Op_Tltu     `Op_Type_R
`define Op_Tne      `Op_Type_R
`define Op_Tnei     `Op_Type_BI
`define Op_Xor      `Op_Type_R
`define Op_Xori     6'b00_1110

/* Op Code Rt fields for Branches & Traps */
`define OpRt_Clear   5'b00000
`define OpRt_Bgez    5'b00001
`define OpRt_Bgezal  5'b10001
`define OpRt_Bgezall 5'b10011
`define OpRt_Bgezl   5'b00011
`define OpRt_Bgtz    `OpRt_Clear
`define OpRt_Bgtzl   `OpRt_Clear
`define OpRt_Blez    `OpRt_Clear
`define OpRt_Blezl   `OpRt_Clear
`define OpRt_Bltz    `OpRt_Clear
`define OpRt_Bltzal  5'b10000
`define OpRt_Bltzall 5'b10010
`define OpRt_Bltzl   5'b00010
`define OpRt_Teqi    5'b01100
`define OpRt_Tgei    5'b01000
`define OpRt_Tgeiu   5'b01001
`define OpRt_Tlti    5'b01010
`define OpRt_Tltiu   5'b01011
`define OpRt_Tnei    5'b01110

/* Op Code Rs fields for Coprocessors */
`define OpRs_MF     5'b00000
`define OpRs_MT     5'b00100
`define OpRs_CO     5'b1xxxx // Used by Eret, TLB{p,r,wi,wr}.
`define OpRs_CO4    1'b1

/* Op Code Cache subinstruction fields (Rt[4:2]) */
`define CacheOpI_Idx_Inv    3'b000 // Index invalidate
`define CacheOpD_Idx_WbInv  3'b000 // Index writeback (valid+dirty) invalidate
`define CacheOpI_Idx_LTag   3'b001 // Index load tag (NI)
`define CacheOpD_Idx_LTag   3'b001 // Index load tag (NI)
`define CacheOpI_Idx_STag   3'b010 // Index store tag
`define CacheOpD_Idx_STag   3'b010 // Index store tag
`define CacheOpI_Adr_HInv   3'b100 // Address hit invalidate
`define CacheOpD_Adr_HInv   3'b100 // Address hit invalidate
`define CacheOpI_Adr_Fill   3'b101 // Address fill (NI)
`define CacheOpD_Adr_HWbInv 3'b101 // Address hit writeback invalidate
`define CacheOpD_Adr_HWb    3'b110 // Address hit writeback
`define CacheOpI_Adr_FL     3'b111 // Address fetch and lock (NI)
`define CacheOpD_Adr_FL     3'b111 // Address fetch and lock (NI)

/* Op Code Cache target cache fields (Rt[1:0]) */
`define CacheOp_I 2'b00  // primary instruction cache
`define CacheOp_D 2'b01  // primary data cache
`define CacheOp_S 2'b11  // secondary cache
`define CacheOp_T 2'b10  // tertiary cache

/* Function Codes for R-Type Op Codes */
`define Funct_Add     6'b10_0000
`define Funct_Addu    6'b10_0001
`define Funct_And     6'b10_0100
`define Funct_Break   6'b00_1101
`define Funct_Clo     6'b10_0001 // same as Addu
`define Funct_Clz     6'b10_0000 // same as Add
`define Funct_Div     6'b01_1010
`define Funct_Divu    6'b01_1011
`define Funct_Jr      6'b00_1000
`define Funct_Jalr    6'b00_1001
`define Funct_Madd    6'b00_0000
`define Funct_Maddu   6'b00_0001
`define Funct_Mfhi    6'b01_0000
`define Funct_Mflo    6'b01_0010
`define Funct_Movn    6'b00_1011
`define Funct_Movz    6'b00_1010
`define Funct_Msub    6'b00_0100 // same as Sllv
`define Funct_Msubu   6'b00_0101
`define Funct_Mthi    6'b01_0001
`define Funct_Mtlo    6'b01_0011
`define Funct_Mul     6'b00_0010 // same as Srl
`define Funct_Mult    6'b01_1000
`define Funct_Multu   6'b01_1001
`define Funct_Nor     6'b10_0111
`define Funct_Or      6'b10_0101
`define Funct_Sll     6'b00_0000
`define Funct_Sllv    6'b00_0100
`define Funct_Slt     6'b10_1010
`define Funct_Sltu    6'b10_1011
`define Funct_Sra     6'b00_0011
`define Funct_Srav    6'b00_0111
`define Funct_Srl     6'b00_0010
`define Funct_Srlv    6'b00_0110
`define Funct_Sub     6'b10_0010
`define Funct_Subu    6'b10_0011
`define Funct_Sync    6'b00_1111
`define Funct_Syscall 6'b00_1100
`define Funct_Teq     6'b11_0100
`define Funct_Tge     6'b11_0000
`define Funct_Tgeu    6'b11_0001
`define Funct_Tlt     6'b11_0010
`define Funct_Tltu    6'b11_0011
`define Funct_Tne     6'b11_0110
`define Funct_Xor     6'b10_0110

/* Non-ALU Function Codes for CP0 Ops */
`define Funct_Eret    6'b01_1000
`define Funct_Tlbp    6'b00_1000
`define Funct_Tlbr    6'b00_0001
`define Funct_Tlbwi   6'b00_0010
`define Funct_Tlbwr   6'b00_0110

/* ALU Operations (Implementation) */
`define AluOp_Add    6'd1
`define AluOp_Addu   6'd0
`define AluOp_And    6'd2
`define AluOp_Clo    6'd3
`define AluOp_Clz    6'd4
`define AluOp_Div    6'd5
`define AluOp_Divu   6'd6
`define AluOp_Madd   6'd7
`define AluOp_Maddu  6'd8
`define AluOp_Mfhi   6'd9
`define AluOp_Mflo   6'd10
`define AluOp_Msub   6'd13
`define AluOp_Msubu  6'd14
`define AluOp_Mthi   6'd11  // XXX TODO can possibly kill this
`define AluOp_Mtlo   6'd12  // XXX TODO can possibly kill this
`define AluOp_Mul    6'd15
`define AluOp_Mult   6'd16
`define AluOp_Multu  6'd17
`define AluOp_Nor    6'd18
`define AluOp_Or     6'd19
`define AluOp_Sll    6'd20
`define AluOp_Lui    6'd21
`define AluOp_Sllv   6'd22
`define AluOp_Slt    6'd23
`define AluOp_Sltu   6'd24
`define AluOp_Sra    6'd25
`define AluOp_Srav   6'd26
`define AluOp_Srl    6'd27
`define AluOp_Srlv   6'd28
`define AluOp_Sub    6'd29
`define AluOp_Subu   6'd30
`define AluOp_Xor    6'd31
`define AluOp_PassA  6'd32
`define AluOp_PassB  6'd33


/* Exception Codes (Implementation; in descending order of priority) */
`define Exc_None     5'd0
`define Exc_Int      5'd1
`define Exc_AdIF     5'd31
`define Exc_TlbRi    5'd3
`define Exc_TlbIi    5'd4
`define Exc_Cachei   5'd5   // NI
`define Exc_Busi     5'd6   // NI
`define Exc_CpU0     5'd7
`define Exc_CpU1     5'd8
`define Exc_CpU2     5'd9
`define Exc_CpU3     5'd10
`define Exc_RI       5'd11
`define Exc_Sys      5'd12
`define Exc_Bp       5'd13
`define Exc_Tr       5'd14
`define Exc_Ov       5'd15
`define Exc_AdEL     5'd16
`define Exc_AdES     5'd17
`define Exc_TlbRLd   5'd18
`define Exc_TlbRSd   5'd19
`define Exc_TlbILd   5'd20
`define Exc_TlbISd   5'd21
`define Exc_TlbMd    5'd22
`define Exc_Cached   5'd23  // NI
`define Exc_Busd     5'd24  // NI


/*** Datapath ***

     All Signals are Active High. Branching and Jump signals (determined by "PCSrc"),
     ALU operations ("ALUOp"), and CP0 signals are handled by the controller and are not found here.

     Bit  Name          Description
     ------------------------------
     19:  PCSrc         (Instruction Type)
     18:                   11: Instruction is Jump to Register
                           10: Instruction is Branch
                           01: Instruction is Jump to Immediate
                           00: Instruction does not branch nor jump
     ------------------------------
     17:  ALUSrc        (ALU Source) [0=ALU input B is 2nd register file output 1=Immediate value]
     16:  Movc          (Conditional Move)
     15:  Trap          (Trap Instruction)
     14:  TrapCond      (Trap Condition) [0=ALU result is 0 1=ALU result is not 0]
     13:  RegDst        (Register File Target) [0=Rt field 1=Rd field]
     ------------------------------
     12:  LLSC          (Load Linked or Store Conditional)
     11:  MemRead       (Data Memory Read)
     10:  MemWrite      (Data Memory Write)
     9 :  MemHalf       (Half Word Memory Access)
     8 :  MemByte       (Byte size Memory Access)
     7 :  MemSignExtend (Sign Extend Read Memory) [0=Zero Extend 1=Sign Extend]
     ------------------------------
     6 :  RegWrite      (Register File Write)
     5 :  ControlWrite  (Writes to CP0, TLB, and/or Caches)
     4 :  MemtoReg      (Memory to Register) [0=Register File write data is ALU output 1=Is Data Memory]
     ------------------------------
     3 :  HiRead        (ALU Hi Read)
     2 :  LoRead        (ALU Lo Read)
     1 :  HiWrite       (ALU Hi Write)
     0 :  LoWrite       (ALU Lo Write)
*/
`define DP_None          20'b00_00000_000000_000_0000    // Instructions which require nothing of the main datapath.
`define DP_RType         20'b00_00001_000000_100_0000    // Standard R-Type
`define DP_IType         20'b00_10000_000000_100_0000    // Standard I-Type
`define DP_Branch        20'b10_00000_000000_000_0000    // Standard Branch
`define DP_BranchLink    20'b10_00000_000000_100_0000    // Branch and Link
`define DP_Jump          20'b01_00000_000000_000_0000    // Standard Jump
`define DP_JumpLink      20'b01_00000_000000_100_0000    // Jump and Link
`define DP_JumpLinkReg   20'b11_00001_000000_100_0000    // Jump and Link Register
`define DP_JumpReg       20'b11_00000_000000_000_0000    // Jump Register
`define DP_LoadByteS     20'b00_10000_010011_101_0000    // Load Byte Signed
`define DP_LoadByteU     20'b00_10000_010010_101_0000    // Load Byte Unsigned
`define DP_LoadHalfS     20'b00_10000_010101_101_0000    // Load Half Signed
`define DP_LoadHalfU     20'b00_10000_010100_101_0000    // Load Half Unsigned
`define DP_LoadWord      20'b00_10000_010000_101_0000    // Load Word
`define DP_ExtWrRt       20'b00_00000_000000_100_0000    // A DP-external write to Rt
`define DP_Movc          20'b00_01001_000000_100_0000    // Conditional Move
`define DP_LoadLinked    20'b00_10000_110000_101_0000    // Load Linked
`define DP_StoreCond     20'b00_10000_101000_101_0000    // Store Conditional
`define DP_StoreByte     20'b00_10000_001010_000_0000    // Store Byte
`define DP_StoreHalf     20'b00_10000_001100_000_0000    // Store Half
`define DP_StoreWord     20'b00_10000_001000_000_0000    // Store Word
`define DP_TrapRegCNZ    20'b00_00110_000000_000_0000    // Trap using Rs and Rt,  non-zero ALU (Tlt,  Tltu,  Tne)
`define DP_TrapRegCZ     20'b00_00100_000000_000_0000    // Trap using RS and Rt,  zero ALU     (Teq,  Tge,   Tgeu)
`define DP_TrapImmCNZ    20'b00_10110_000000_000_0000    // Trap using Rs and Imm, non-zero ALU (Tlti, Tltiu, Tnei)
`define DP_TrapImmCZ     20'b00_10100_000000_000_0000    // Trap using Rs and Imm, zero ALU     (Teqi, Tgei,  Tgeiu)
`define DP_HiLoW         20'b00_00000_000000_000_0011    // Write to HiLo ALU register (Div,Divu,Mult,Multu)
`define DP_HiLoWRegW     20'b00_00001_000000_100_0011    // Write to HiLo ALU register and GPR (mul)
`define DP_HiW           20'b00_00000_000000_000_0010    // Write to Hi ALU register (Mthi)
`define DP_LoW           20'b00_00000_000000_000_0001    // Write to Lo ALU register (Mtlo)
`define DP_HiLoRW        20'b00_00000_000000_000_1111    // Read from and write to HiLo ALU register (Madd,Maddu,Msub,Msubu)
`define DP_HiRRegW       20'b00_00001_000000_100_1000    // Read from Hi ALU register and write to GPR (mfhi)
`define DP_LoRRegW       20'b00_00001_000000_100_0100    // Read from Lo ALU register and write to GPR (mflo)
`define DP_ControlWrite  20'b00_00001_000000_010_0000    // Write to CP0, TLB, or Caches (RegDst is for Mtc0)
`define DP_CacheOp       20'b00_10000_000000_010_0000    // Cache operation (same as DP_ControlWrite but requires immediate)
//--------------------------------------------------------
`define DP_Add     `DP_RType
`define DP_Addi    `DP_IType
`define DP_Addiu   `DP_IType
`define DP_Addu    `DP_RType
`define DP_And     `DP_RType
`define DP_Andi    `DP_IType
`define DP_Beq     `DP_Branch
`define DP_Beql    `DP_Branch
`define DP_Bgez    `DP_Branch
`define DP_Bgezal  `DP_BranchLink
`define DP_Bgezall `DP_BranchLink
`define DP_Bgezl   `DP_Branch
`define DP_Bgtz    `DP_Branch
`define DP_Bgtzl   `DP_Branch
`define DP_Blez    `DP_Branch
`define DP_Blezl   `DP_Branch
`define DP_Bltz    `DP_Branch
`define DP_Bltzal  `DP_BranchLink
`define DP_Bltzall `DP_BranchLink
`define DP_Bltzl   `DP_Branch
`define DP_Bne     `DP_Branch
`define DP_Bnel    `DP_Branch
`define DP_Break   `DP_None
`define DP_Cache   `DP_CacheOp
`define DP_Clo     `DP_RType
`define DP_Clz     `DP_RType
`define DP_Div     `DP_HiLoW
`define DP_Divu    `DP_HiLoW
`define DP_Eret    `DP_ControlWrite
`define DP_J       `DP_Jump
`define DP_Jal     `DP_JumpLink
`define DP_Jalr    `DP_JumpLinkReg
`define DP_Jr      `DP_JumpReg
`define DP_Lb      `DP_LoadByteS
`define DP_Lbu     `DP_LoadByteU
`define DP_Lh      `DP_LoadHalfS
`define DP_Lhu     `DP_LoadHalfU
`define DP_Ll      `DP_LoadLinked
`define DP_Lui     `DP_IType
`define DP_Lw      `DP_LoadWord
`define DP_Lwl     `DP_LoadWord
`define DP_Lwr     `DP_LoadWord
`define DP_Madd    `DP_HiLoRW
`define DP_Maddu   `DP_HiLoRW
`define DP_Mfc0    `DP_ExtWrRt
`define DP_Mfhi    `DP_HiRRegW
`define DP_Mflo    `DP_LoRRegW
`define DP_Movn    `DP_Movc
`define DP_Movz    `DP_Movc
`define DP_Msub    `DP_HiLoRW
`define DP_Msubu   `DP_HiLoRW
`define DP_Mtc0    `DP_ControlWrite
`define DP_Mthi    `DP_HiW
`define DP_Mtlo    `DP_LoW
`define DP_Mul     `DP_HiLoWRegW
`define DP_Mult    `DP_HiLoW
`define DP_Multu   `DP_HiLoW
`define DP_Nor     `DP_RType
`define DP_Or      `DP_RType
`define DP_Ori     `DP_IType
`define DP_Pref    `DP_None // Not Implemented
`define DP_Sb      `DP_StoreByte
`define DP_Sc      `DP_StoreCond
`define DP_Sh      `DP_StoreHalf
`define DP_Sll     `DP_RType
`define DP_Sllv    `DP_RType
`define DP_Slt     `DP_RType
`define DP_Slti    `DP_IType
`define DP_Sltiu   `DP_IType
`define DP_Sltu    `DP_RType
`define DP_Sra     `DP_RType
`define DP_Srav    `DP_RType
`define DP_Srl     `DP_RType
`define DP_Srlv    `DP_RType
`define DP_Sub     `DP_RType
`define DP_Subu    `DP_RType
`define DP_Sw      `DP_StoreWord
`define DP_Swl     `DP_StoreWord
`define DP_Swr     `DP_StoreWord
`define DP_Sync    `DP_None
`define DP_Syscall `DP_None
`define DP_Teq     `DP_TrapRegCZ
`define DP_Teqi    `DP_TrapImmCZ
`define DP_Tge     `DP_TrapRegCZ
`define DP_Tgei    `DP_TrapImmCZ
`define DP_Tgeiu   `DP_TrapImmCZ
`define DP_Tgeu    `DP_TrapRegCZ
`define DP_Tlbp    `DP_ControlWrite
`define DP_Tlbr    `DP_ControlWrite
`define DP_Tlbwi   `DP_ControlWrite
`define DP_Tlbwr   `DP_ControlWrite
`define DP_Tlt     `DP_TrapRegCNZ
`define DP_Tlti    `DP_TrapImmCNZ
`define DP_Tltiu   `DP_TrapImmCNZ
`define DP_Tltu    `DP_TrapRegCNZ
`define DP_Tne     `DP_TrapRegCNZ
`define DP_Tnei    `DP_TrapImmCNZ
`define DP_Xor     `DP_RType
`define DP_Xori    `DP_IType


/*** Hazard & Forwarding Datapath ***

     All signals are Active High.

     Bit  Meaning
     ------------
     12:   Wants Rs by D2
     11:   Needs Rs by D2
     10:   Wants Rt by D2
     9:    Needs Rt by D2
     --
     8:    Wants Rs by X1
     7:    Needs Rs by X1
     6:    Wants Rt by X1
     5:    Needs Rt by X1
     --
     4:    Wants Rs by M1
     3:    Wants Rt by M1
     2:    Needs Rt by M1
     --
     1:    Wants Rs by M2
     0:    Wants Rt by M2
*/
`define HAZ_DC        13'bxxxx_xxxx_xxx_xx
`define HAZ_Nothing   13'b0000_0000_000_00  // Jumps, lui, mfhi/lo, special, etc.
`define HAZ_D2RsD2Rt  13'b1111_0000_000_00  // beq, bne
`define HAZ_D2Rs      13'b1100_0000_000_00  // Most branches (bgez, bgezal, bgtz, blez, bltz, bltzal)
`define HAZ_X1RsX1Rt  13'b1010_1111_000_00  // Many R-type ops
`define HAZ_X1Rs      13'b1000_1100_000_00  // Immediates: Loads, clo/z, mthi/lo, etc.
`define HAZ_X1RsM1Rt  13'b1010_1110_011_00  // Stores
`define HAZ_X1Rt      13'b0010_0011_000_00  // Shifts using Shamt field
`define HAZ_W1Rs      13'b1000_1000_100_10  // mthi, mtlo
`define HAZ_W1RsX1Rt  13'b1010_1011_100_10  // movc, movn
`define HAZ_W1Rt      13'b0010_0010_010_01  // mtc0
//----------------------------------------
`define HAZ_Add     `HAZ_X1RsX1Rt
`define HAZ_Addi    `HAZ_X1Rs
`define HAZ_Addiu   `HAZ_X1Rs
`define HAZ_Addu    `HAZ_X1RsX1Rt
`define HAZ_And     `HAZ_X1RsX1Rt
`define HAZ_Andi    `HAZ_X1Rs
`define HAZ_Beq     `HAZ_D2RsD2Rt
`define HAZ_Beql    `HAZ_D2RsD2Rt
`define HAZ_Bgez    `HAZ_D2Rs
`define HAZ_Bgezal  `HAZ_D2Rs
`define HAZ_Bgezall `HAZ_D2Rs
`define HAZ_Bgezl   `HAZ_D2Rs
`define HAZ_Bgtz    `HAZ_D2Rs
`define HAZ_Bgtzl   `HAZ_D2Rs
`define HAZ_Blez    `HAZ_D2Rs
`define HAZ_Blezl   `HAZ_D2Rs
`define HAZ_Bltz    `HAZ_D2Rs
`define HAZ_Bltzal  `HAZ_D2Rs
`define HAZ_Bltzall `HAZ_D2Rs
`define HAZ_Bltzl   `HAZ_D2Rs
`define HAZ_Bne     `HAZ_D2RsD2Rt
`define HAZ_Bnel    `HAZ_D2RsD2Rt
`define HAZ_Break   `HAZ_Nothing
`define HAZ_Cache   `HAZ_X1Rs
`define HAZ_Clo     `HAZ_X1Rs
`define HAZ_Clz     `HAZ_X1Rs
`define HAZ_Div     `HAZ_X1RsX1Rt
`define HAZ_Divu    `HAZ_X1RsX1Rt
`define HAZ_Eret    `HAZ_Nothing
`define HAZ_J       `HAZ_Nothing
`define HAZ_Jal     `HAZ_Nothing
`define HAZ_Jalr    `HAZ_D2Rs
`define HAZ_Jr      `HAZ_D2Rs
`define HAZ_Lb      `HAZ_X1Rs
`define HAZ_Lbu     `HAZ_X1Rs
`define HAZ_Lh      `HAZ_X1Rs
`define HAZ_Lhu     `HAZ_X1Rs
`define HAZ_Ll      `HAZ_X1Rs
`define HAZ_Lui     `HAZ_Nothing
`define HAZ_Lw      `HAZ_X1Rs
`define HAZ_Lwl     `HAZ_X1RsM1Rt
`define HAZ_Lwr     `HAZ_X1RsM1Rt
`define HAZ_Madd    `HAZ_X1RsX1Rt
`define HAZ_Maddu   `HAZ_X1RsX1Rt
`define HAZ_Mfc0    `HAZ_Nothing
`define HAZ_Mfhi    `HAZ_Nothing
`define HAZ_Mflo    `HAZ_Nothing
`define HAZ_Movn    `HAZ_W1RsX1Rt
`define HAZ_Movz    `HAZ_W1RsX1Rt
`define HAZ_Msub    `HAZ_X1RsX1Rt
`define HAZ_Msubu   `HAZ_X1RsX1Rt
`define HAZ_Mtc0    `HAZ_W1Rt
`define HAZ_Mthi    `HAZ_W1Rs
`define HAZ_Mtlo    `HAZ_W1Rs
`define HAZ_Mul     `HAZ_X1RsX1Rt
`define HAZ_Mult    `HAZ_X1RsX1Rt
`define HAZ_Multu   `HAZ_X1RsX1Rt
`define HAZ_Nor     `HAZ_X1RsX1Rt
`define HAZ_Or      `HAZ_X1RsX1Rt
`define HAZ_Ori     `HAZ_X1Rs
`define HAZ_Pref    `HAZ_X1Rs
`define HAZ_Sb      `HAZ_X1RsM1Rt
`define HAZ_Sc      `HAZ_X1RsM1Rt
`define HAZ_Sh      `HAZ_X1RsM1Rt
`define HAZ_Sll     `HAZ_X1Rt
`define HAZ_Sllv    `HAZ_X1RsX1Rt
`define HAZ_Slt     `HAZ_X1RsX1Rt
`define HAZ_Slti    `HAZ_X1Rs
`define HAZ_Sltiu   `HAZ_X1Rs
`define HAZ_Sltu    `HAZ_X1RsX1Rt
`define HAZ_Sra     `HAZ_X1Rt
`define HAZ_Srav    `HAZ_X1RsX1Rt
`define HAZ_Srl     `HAZ_X1Rt
`define HAZ_Srlv    `HAZ_X1RsX1Rt
`define HAZ_Sub     `HAZ_X1RsX1Rt
`define HAZ_Subu    `HAZ_X1RsX1Rt
`define HAZ_Sw      `HAZ_X1RsM1Rt
`define HAZ_Swl     `HAZ_X1RsM1Rt
`define HAZ_Swr     `HAZ_X1RsM1Rt
`define HAZ_Sync    `HAZ_Nothing
`define HAZ_Syscall `HAZ_Nothing
`define HAZ_Teq     `HAZ_X1RsX1Rt
`define HAZ_Teqi    `HAZ_X1Rs
`define HAZ_Tge     `HAZ_X1RsX1Rt
`define HAZ_Tgei    `HAZ_X1Rs
`define HAZ_Tgeiu   `HAZ_X1Rs
`define HAZ_Tgeu    `HAZ_X1RsX1Rt
`define HAZ_Tlbp    `HAZ_Nothing
`define HAZ_Tlbr    `HAZ_Nothing
`define HAZ_Tlbwi   `HAZ_Nothing
`define HAZ_Tlbwr   `HAZ_Nothing
`define HAZ_Tlt     `HAZ_X1RsX1Rt
`define HAZ_Tlti    `HAZ_X1Rs
`define HAZ_Tltiu   `HAZ_X1Rs
`define HAZ_Tltu    `HAZ_X1RsX1Rt
`define HAZ_Tne     `HAZ_X1RsX1Rt
`define HAZ_Tnei    `HAZ_X1Rs
`define HAZ_Xor     `HAZ_X1RsX1Rt
`define HAZ_Xori    `HAZ_X1Rs

