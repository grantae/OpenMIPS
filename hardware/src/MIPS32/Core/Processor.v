`timescale 1ns / 1ps
/*
 * File         : Processor.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   23-Jul-2011  GEA       Initial design.
 *   Future revisions are tracked in source control.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The top-level MIPS32 Release 1 processor core.
 *   This unit is designed to integrate with an instruction and data cache.
 */
module Processor #(parameter PABITS=36) (
    input                   clock,
    input                   reset,
    // Instruction Memory Interface
    output [9:0]            InstMem_VAddress,      // Bits [11:2] of the 32-bit virtual / 36-bit physical instruction address
    output [(PABITS-13):0]  InstMem_PAddress,      // Bits [35:12] of the 36-bit physical instruction address
    output                  InstMem_PAddressValid, // TLB hit
    output [2:0]            InstMem_CacheAttr,     // Cacheability attributes for the given address
    output                  InstMem_Read,          // Read command to instruction memory
    output                  InstMem_Stall,         // Inform the i-cache to hold its data due to a processor stall
    output                  InstMem_DoCacheOp,     // Perform an administrative operation on the i-cache
    output [2:0]            InstMem_CacheOp,       // Operation to perform on the i-cache
    output [(PABITS-11):0]  InstMem_CacheOpData,   // Tag data for an i-cache operation (12-bit index)
    input  [31:0]           InstMem_In,            // Inbound instruction
    input                   InstMem_Ready,         // The instruction at 'InstMem_In' is valid
    input                   InstMem_Blocked,       // The instruction cache cannot be cancelled/interrupted
    // Data Memory Interface
    output [9:0]            DataMem_VAddress,      // Bits [11:2] of the 32-bit virtual / 36-bit physical data memory address
    output [(PABITS-13):0]  DataMem_PAddress,      // Bits [35:12] of the 36-bit physical data memory address
    output                  DataMem_PAddressValid, // TLB hit
    output [2:0]            DataMem_CacheAttr,     // Cacheability attributes for the given address
    output                  DataMem_Read,          // Read command: One word
    output [3:0]            DataMem_Write,         // Write command: One bit for each byte in the word
    output [31:0]           DataMem_Out,           // Outbound data (store)
    output                  DataMem_Stall,         // Inform the d-cache to hold its data due to a processor stall
    output                  DataMem_DoCacheOp,     // Perform an administrative operation on the d-cache
    output [2:0]            DataMem_CacheOp,       // Operation to perform on the d-cache
    output [(PABITS-9):0]   DataMem_CacheOpData,   // Tag data for a d-cache operation (10-bit index)
    input  [31:0]           DataMem_In,            // Inbound data (load)
    input                   DataMem_Ready,         // The data at 'DataMem_In' is valid
    // External interrupts
    input  [4:0]            Interrupts,            // 5 general-purpose hardware interrupts
    input                   NMI                    // Non-maskable interrupt
    );

    `include "MIPS_Defines.v"

    /* Component Locations:
     *   F1: PC, PC+4 adder, I$, TLB
     *   F2: I$ and TLB result
     *   D1: RF, Branch adder, Sign extend, jump shift
     *   D2: Fwd muxes, Branch logic, Control logic, CP0 read
     *   X1: ALU computation, trap detection (???)
     *   M1: Memory access start
     *   M2: Memory access finish
     *   W1: ... Interrupt detection (takes priority over most other exceptions)
     */

    /* Pipeline Flow Logic:
     *
     * - The 'Issued' signal in a pipeline stage signifies that the stage contains a programmed instruction
     *   whose execution is in progress. Therefore it has a valid RestartPC, it is not a pipeline stall, it
     *   has not been flushed, and it has not caused an exception. This bit cannot transition from 0->1.
     *   It is typically the combination of (PriorIssued & ~Mask).
     *
     * - The 'Mask' signal in a pipeline stage signifies that the stage is being de-issued due to a stall,
     *   flush, or exception. It causes the next stage to latch a non-issued, no-exception instruction.
     *   It is typically the combination of (Stall | Flush | Exception).
     *
     * - When a pipeline stage stalls:
     *     1. Its own state registers are disabled (e.g., D2_Stall -> D2_Stage doesn't latch).
     *     2. The next stage latches a non-issued, no-exception instruction.
     *     3. The stall chains to cause all previous stages to stall.
     *
     * - When a pipeline stage flushes:
     *     1. It clears its own 'Issued' bit which masks all state-changing control signals in the stage.
     *     2. The next stage latches a non-issued, no-exception instruction.
     *
     * - Control signals (regwrite, memread, etc.) are ANDed with 'Issued' in their respective stages.
     *
     * - When a stage causes an exception, 'Issued' is cleared, 'Exception' is set,  and the 'ExcCode' bits
     *   are set to describe it. No exception bits can be set by a non-issued stage.
     *
     * - An exception is detected in W1 when 'Exception' is set. It causes all stages to flush.
     *
     * - Memory writes could be delayed until W1, but it would require more state and we can mask them in M2
     *   if the TLB missed or if W1 has an exception.
     *
     */

    /* Branch and Jump Logic:
     *
     * - A taken branch/jump is resolved in D2.
     * - D2 sends 'IsBDS' to D1, which will allow the final computation of 'RestartPC' for the first time in D2.
     *   (Before D2 RestartPC will be invalid for delay slots). XXX DO WE NEED FINAL RESTARTPC EARLIER?
     * - F2 flushes and F1 either flushes or disables a memory read.
     *
     * New stuff: Instruction fetches are variable delay, so when a jmp/branch is in D2, the BDS can
     * either be in D1 or F2 (it can't be in F1 since we know it was requested).
     *
     * If BDS is in D1, we set BDS in D1 and flush F2/F1(?).
     * If BDS is in F2, we flush F1(?) and keep F2 (Flush D1 not needed since already ~issued)
     * So, how to tell? Check if D1 is Issued (D1_F2Issued). If yes, it's the BDS. Otherwise it's F2.
     *
     * Summary: F1 Flush: "D2_Branch", F2 Flush: "D2_Branch & D1_F2Issued"
     */

    //*** Instruction Fetch 1 (F1) Signals ***//
    wire        F1_Stall;               // Kind of like ~F1_Enable; basically no instruction fetch
    wire        F1_Flush;
    wire        F1_Mask_Haz;
    wire        F1_Mask_Exc;
    wire        F1_XOP_Restart;         // A 2nd fetch of an XOP which should be skipped
    wire        F1_Issued;
    wire        F1_Exception;
    wire [4:0]  F1_ExcCode;             // Exception code occuring in F1
    wire [31:0] F1_PC;                  // Authoritative program counter for instruction memory
    wire [31:0] F1_PCAdd4;              // PC+4 for non-branch, non-exception
    wire [31:0] F1_PCAdd4_XOP;          // PC+4 for non-branch, non-exception after XOP restart PC mux
    wire        F1_EXC_AdIF;            // Address fetch exception
    wire        F1_DoICacheOp;
    wire [2:0]  F1_ICacheOp;
    wire [(PABITS-11):0] F1_ICacheOpData; // Store tag data for i-cache operation

    //*** Instruction Fetch 2 (F2) Signals ***//
    wire        F2_Stall;               // Pipeline stall
    wire        F2_Cache_Stall;
    wire        F2_NonMem_Stall;
    wire        F2_Flush;
    wire        F2_Mask_Haz;
    wire        F2_Mask_Exc;
    wire        F2_Mask_XOP_BL;         // An instruction mask due to either an XOP or branch likely instruction
    wire        F2_XOP_Restart;         // A 2nd fetch of an XOP which should be skipped
    wire        F2_F1Issued;
    wire        F2_F1DoICacheOp;        // An i-cache operation occurred in F1 (used to mask 'Issued' when complete)
    wire        F2_Issued;              // A non-stalled, non-flushed, real (not 'bubbled') instruction
    wire        F2_F1Exception;
    wire        F2_Exception;
    wire [4:0]  F2_F1ExcCode;
    wire [1:0]  F2_ExcCodes;
    reg  [4:0]  F2_ExcCode;             // Exception code occuring in F2
    wire        F2_IsBDS;               // F2 is a branch delay slot
    wire [(PABITS-13):0] F2_PFN;        // Instruction memory physical address translation
    wire        F2_PFN_Valid;           // Instruction memory translation is valid
    wire [2:0]  F2_Cache;               // Instruction memory cache attributes
    wire [31:0] F2_Instruction;         // Instruction incoming from the cache
    wire [31:0] F2_FetchPC;             // Program counter for exceptions, will become 'RestartPC' by D2.
    wire [31:0] F2_PCAdd4;              // Address of next instruction for future branch calculation
    wire        F2_EXC_TlbRi;           // Instruction memory TLB refill exception
    wire        F2_EXC_TlbIi;           // Instruction memory TLB invalid exception

    //*** Instruction Decode 1 (D1) Signals ***//
    wire        D1_Stall;               // Pipeline stall
    wire        D1_Flush;
    wire        D1_Mask_Haz;
    wire        D1_Mask_XOP_BL;         // An instruction mask due to either an XOP or branch likely instruction
    wire        D1_XOP_Restart;         // A 2nd fetch of an XOP which should be skipped
    wire        D1_F2Issued;
    wire        D1_Issued;              // An instruction is executing in D1
    wire        D1_F2Exception;
    wire        D1_Exception;
    wire [4:0]  D1_F2ExcCode;           // Exception code from F1,F2
    wire [4:0]  D1_ExcCode;             // Exception code occuring in D1
    wire [31:0] D1_FetchPC;             // Program counter for exceptions (RestartPC after D2)
    wire [31:0] D1_PCAdd4;              // Address of the next instruction for branch calculation
    wire        D1_IsBDS;               // D1 is a branch delay slot
    wire        D1_JumpIInst;           // D1 is a jump immediate instruction (j / jal)
    wire [31:0] D1_JumpIAddress;        // 4-bit region with 26-bit instruction index all multiplied by four (jump immediate)
    wire [31:0] D1_JumpIBrAddr;         // Selection of either the immediate jump or branch address in D1 (a predecoding optimization)
    wire        D1_F2IsBDS;
    wire [31:0] D1_Instruction;         // MIPS instruction
    wire [4:0]  D1_Rs;                  // Rs register index
    wire [4:0]  D1_Rt;                  // Rt register index
    wire [4:0]  D1_Rd;                  // Rd register index
    wire [2:0]  D1_Sel;                 // CP0 subregister select index
    wire [15:0] D1_Immediate;           // 16-bit immediate value from an instruction
    wire [29:0] D1_SignExtImm;          // 16-bit immediate sign-extended to 30 bits
    wire [31:0] D1_SignExtImmShift;     // 16-bit immediate sign-extended then multiplied by four
    wire [31:0] D1_BranchAddress;       // PC+4 + SE(D1_Immediate << 2)
    wire [3:0]  D1_JumpRegion;          // Top four bits of PC+4 for a 256-MB jump region
    wire        D1_RsFwdSel;
    wire        D1_RtFwdSel;
    wire [31:0] D1_ReadData1;           // Rs data from the register file
    wire [31:0] D1_ReadData1_End;
    wire [31:0] D1_ReadData2;           // Rt data from the register file
    wire [31:0] D1_ReadData2_End;
    wire [31:0] D1_Cp0_ReadData;        // Cp0 read data (mfc0)

    //*** Instruction Decode 2 (D2) Signals ***//
    wire        D2_Stall;               // Pipeline stall
    wire        D2_Flush;
    wire        D2_Mask_Haz;
    wire        D2_Mask_Exc;
    wire        D2_Mask_XOP;
    wire        D2_XOP_Restart;         // A 2nd fetch of an XOP which should be skipped
    wire        D2_D1Issued;
    wire        D2_Issued;
    wire        D2_D1Exception;
    wire        D2_Exception;
    wire [4:0]  D2_D1ExcCode;
    reg  [4:0]  D2_ExcCode;
    wire [31:0] D2_Instruction;         // MIPS instruction
    wire [5:0]  D2_OpCode;              // MIPS instruction opcode
    wire [4:0]  D2_Rs;                  // Rs register index
    wire [4:0]  D2_Rt;                  // Rt register index
    wire [5:0]  D2_Funct;               // MIPS instruction function code
    wire        D2_Branch;              // A jump/branch being taken
    wire [31:0] D2_SZExtImm;            // Sign- or zero-extended immediate field of the instruction
    wire [31:0] D2_RestartPC;           // Restart program counter for exceptions
    wire        D2_IsBDS;
    wire [31:0] D2_JumpIBrAddr;         // Selection of either the immediate jump address or a branch address in D2
    wire [31:0] D2_JumpRAddress;        // Rs-supplied register jump address
    wire [31:0] D2_ReadData1;           // Rs data from the register file
    wire [31:0] D2_ReadData1_Cp0;
    wire [31:0] D2_ReadData1_End;       // ReadData1 as it enters X1 (after forwarding and muxes)
    wire [31:0] D2_ReadData2;           // Rt data from the register file
    wire [31:0] D2_Cp0_ReadData;
    wire [31:0] D2_ReadData2_Link;      // Rt/ReadData2 after link address selection
    wire [31:0] D2_ReadData2_End;       // ReadData2 as it enters X1 (after forwarding and muxes)
    wire [1:0]  D2_PCSrc_Br;            // Datapath signal selecting {PC+4, Branch, Jumpi, Jumpr} PC addresses (not necessarily taken)
    wire [1:0]  D2_PCSrc_Sel;           // Final PC selection after considering exceptions and other pipeline details
    wire        D2_PCSrc_Exc;           // Control signal selecting normal or exception PC addresses
    wire        D2_NextIsBDS;           // D2 has a branch/jump instruction so the next instruction is a delay slot
    wire        D2_BDSMask;             // D2 has a 'branch likely' instruction which masks the delay slot because it isn't being taken
    wire [31:0] D2_ExceptionPC;         // Exception PC from CP0
    wire [31:0] D2_PC;                  // Authoritative input to the PC
    wire [1:0]  D2_RsFwdSel;
    wire [1:0]  D2_RtFwdSel;
    wire        D2_ALUSrcImm;
    wire        D2_Movn;
    wire        D2_Movz;
    wire        D2_Trap;
    wire        D2_TrapCond;
    wire        D2_RegDst;
    wire        D2_LLSC;
    wire        D2_MemRead;
    wire        D2_MemWrite;
    wire        D2_MemHalf;
    wire        D2_MemByte;
    wire        D2_MemSignExtend;
    wire        D2_RegWrite;
    wire        D2_LoRead;
    wire        D2_HiWrite;
    wire        D2_LoWrite;
    wire        D2_MemToReg;
    wire [12:0] D2_DP_Hazards;
    wire [5:0]  D2_X1_DP_Hazards;
    wire        D2_Left;
    wire        D2_Right;
    wire        D2_SignExtend;          // Control signal for sign/zero extension
    wire        D2_Link;
    wire        D2_LinkReg;
    wire        [5:0] D2_ALUOp;
    wire        D2_Mfc0;
    wire        D2_Mtc0;
    wire        D2_Eret;
    wire        D2_TLBp;
    wire        D2_TLBr;
    wire        D2_TLBwi;
    wire        D2_TLBwr;
    wire        D2_ICacheOp;
    wire        D2_DCacheOp;
    wire        D2_XOP;
    wire        D2_CP0;                 // Cp0 access instruction in D2 (cache, eret, mfc0, mtc0, tlb{p,r,wi,wr})
    wire        D2_CP1;
    wire        D2_CP2;
    wire        D2_CP3;
    wire        D2_EXC_Bp;
    wire        D2_EXC_Sys;
    wire        D2_EXC_RI;
    wire        D2_EXC_CpU0;
    wire        D2_EXC_CpU1;
    wire        D2_EXC_CpU2;
    wire        D2_EXC_CpU3;
    wire [6:0]  D2_ExcCodes;
    wire [31:0] D2_BadVAddr;

    //*** Execute (X1) Signals ***//
    wire        X1_Stall;
    wire        X1_Flush;
    wire        X1_Mask_Haz;
    wire        X1_Mask_Exc;
    wire        X1_D2Issued;
    wire        X1_Issued;
    wire        X1_D2Exception;
    wire        X1_Exception;
    wire [4:0]  X1_D2ExcCode;
    reg  [4:0]  X1_ExcCode;
    wire [31:0] X1_RestartPC;
    wire        X1_IsBDS;
    wire [5:0]  X1_DP_Hazards;
    wire [1:0]  X1_M1_DP_Hazards;
    wire [4:0]  X1_Rs;
    wire [4:0]  X1_Rt;
    wire [4:0]  X1_RtRd_PreLink;
    wire [4:0]  X1_RtRd;
    wire [2:0]  X1_CP0Sel;
    wire [31:0] X1_ReadData1;
    wire [31:0] X1_ReadData2;
    wire [1:0]  X1_RsFwdSel;
    wire [1:0]  X1_RtFwdSel;
    wire [31:0] X1_SZExtImm;
    wire [4:0]  X1_Shamt;
    wire        X1_ALUSrcImm;
    wire        X1_Movn;
    wire        X1_Movz;
    wire        X1_Trap;
    wire        X1_TrapCond;
    wire        X1_RegDst;
    wire        X1_LLSC;
    wire        X1_MemRead;
    wire        X1_MemWrite;
    wire        X1_MemHalf;
    wire        X1_MemByte;
    wire        X1_Left;
    wire        X1_Right;
    wire        X1_MemSignExtend;
    wire        X1_Link;
    wire        X1_LinkReg;
    wire        X1_Div;
    wire        X1_RegWrite;
    wire        X1_HiRead;
    wire        X1_LoRead;
    wire        X1_HiWrite;
    wire        X1_LoWrite;
    wire        X1_MemToReg;
    wire [31:0] X1_ReadData1_Link;
    wire [31:0] X1_ReadData1_End;
    wire [31:0] X1_ReadData2_Fwd;
    wire [31:0] X1_ReadData2_End;
    wire [5:0]  X1_ALUOp;
    wire [31:0] X1_ALUInA;
    wire [31:0] X1_ALUInB;
    wire [31:0] X1_ALUResult;
    wire [31:0] X1_WriteData;
    wire        X1_BZero;
    wire        X1_EXC_Ov;
    wire        X1_Mtc0;
    wire        X1_TLBp;
    wire        X1_TLBr;
    wire        X1_TLBwi;
    wire        X1_TLBwr;
    wire        X1_ICacheOp;
    wire        X1_DCacheOp;
    wire        X1_Eret;
    wire        X1_XOP;
    wire [31:0] X1_BadVAddr;

    //*** Memory 1 (M1) Signals ***//
    wire        M1_Stall;
    wire        M1_Flush;
    wire        M1_Mask_Haz;
    wire        M1_Mask_Exc;
    wire        M1_X1Issued;
    wire        M1_Issued;
    wire        M1_X1Exception;
    wire        M1_Exception;
    wire [4:0]  M1_X1ExcCode;
    reg  [4:0]  M1_ExcCode;
    wire [31:0] M1_RestartPC;
    wire        M1_IsBDS;
    wire [1:0]  M1_DP_Hazards;
    wire [4:0]  M1_Rt;
    wire [4:0]  M1_RtRd;
    wire [2:0]  M1_CP0Sel;
    wire [1:0]  M1_RtFwdSel;
    wire        M1_Trap;
    wire        M1_TrapCond;
    wire        M1_LLSC;
    wire        M1_MemRead;
    wire        M1_MemWrite;
    wire        M1_MemHalf;
    wire        M1_MemByte;
    wire        M1_Left;
    wire        M1_Right;
    wire        M1_MemSignExtend;
    wire        M1_BigEndian;
    wire        M1_Div;
    wire        M1_RegWrite;
    wire        M1_HiWrite;
    wire        M1_LoWrite;
    wire        M1_MemToReg;
    wire [31:0] M1_ALUResult;
    wire [31:0] M1_WriteData;
    wire [31:0] M1_WriteData_End;
    wire        M1_ReverseEndian;
    wire        M1_KernelMode;
    wire        M1_EXC_AdEL;
    wire        M1_EXC_AdES;
    wire        M1_EXC_Tr;
    wire        M1_Mtc0;
    wire        M1_TLBp;
    wire        M1_TLBr;
    wire        M1_TLBwi;
    wire        M1_TLBwr;
    wire        M1_ICacheOp;
    wire        M1_DCacheOp;
    wire        M1_Eret;
    wire        M1_XOP;
    wire [2:0]  M1_ExcCodes;
    wire [31:0] M1_X1BadVAddr;
    wire [31:0] M1_BadVAddr;

    //*** Memory 2 (M2) Signals ***//
    wire        M2_Stall;
    wire        M2_Cache_Stall;         // Cache miss (when we care)
    wire        M2_NonMem_Stall;
    wire        M2_Flush;
    wire        M2_Mask_Haz;
    wire        M2_Mask_Exc;
    wire        M2_M1Issued;
    wire        M2_Issued;
    wire        M2_M1Exception;
    wire        M2_Exception;
    wire [4:0]  M2_M1ExcCode;
    reg  [4:0]  M2_ExcCode;
    wire [31:0] M2_RestartPC;
    wire        M2_IsBDS;
    wire [(PABITS-13):0] M2_PFN;        // Data memory physical address translation
    wire        M2_PFN_Valid;           // Data memory translation is valid
    wire [2:0]  M2_Cache;               // Data memory cache attributes
    wire [4:0]  M2_RtRd;
    wire [2:0]  M2_CP0Sel;
    wire        M2_LLSC;
    wire        M2_SC;
    wire        M2_Atomic;
    wire        M2_MemRead;
    wire        M2_MemReadIssued;
    wire        M2_MemWrite;
    wire        M2_MemWriteIssued;
    wire        M2_MemHalf;
    wire        M2_MemByte;
    wire        M2_Left;
    wire        M2_Right;
    wire        M2_MemSignExtend;
    wire        M2_BigEndian;
    wire        M2_Div;
    wire        M2_RegWrite;
    wire        M2_HiWrite;
    wire        M2_LoWrite;
    wire        M2_MemToReg;
    wire [31:0] M2_ALUResult;
    wire [31:0] M2_UnalignedReg;
    wire [31:0] M2_ReadData;
    wire        M2_Mtc0;
    wire        M2_TLBp;
    wire        M2_TLBr;
    wire        M2_TLBwi;
    wire        M2_TLBwr;
    wire [3:0]  M2_Index_Out;
    wire [3:0]  M2_Random_Out;
    wire [3:0]  M2_TLBIndex;
    wire        M2_ICacheOp;
    wire        M2_Eret;
    wire        M2_XOP;
    wire        M2_Tlbp_Hit;
    wire [3:0]  M2_Tlbp_Index;
    wire [(29+(2*PABITS)):0] M2_Tlbr_result;
    wire        M2_EXC_TlbRLd;
    wire        M2_EXC_TlbRSd;
    wire        M2_EXC_TlbILd;
    wire        M2_EXC_TlbISd;
    wire        M2_EXC_TlbMd;
    wire [4:0]  M2_ExcCodes;
    wire [31:0] M2_M1BadVAddr;
    wire [31:0] M2_BadVAddr;

    //*** Writeback (W1) Signals ***//
    wire        W1_NonMem_Stall;
    wire        W1_Stall;
    wire        W1_Flush;               // A processor-wide pipeline flush begins here
    wire        W1_Flush_Pending;       // Same as W1_Flush but without waiting for a busy i-cache
    wire        Enabled_Int;            // Interrupt ready, but not yet active (assigned by CPZero)
    wire        W1_ExcDetected;         // Includes exceptions, interrupts, and NMI
    wire        W1_ExcActive;
    wire        W1_M2Issued;
    wire        W1_Issued;
    wire        W1_M2Exception;
    wire [4:0]  W1_M2ExcCode;
    reg  [4:0]  W1_ExcCode;
    wire [31:0] W1_RestartPC;
    wire        W1_IsBDS;
    wire        W1_M2MemRWIssued;       // A memory read/write of any type occured in M2 (used to mask interrupts in W1)
    wire [4:0]  W1_RtRd;                // Write register index
    wire [2:0]  W1_CP0Sel;
    wire        W1_Div;
    wire        W1_RegWrite;            // Control signal for writing to the register file (unmasked)
    wire        W1_HiWrite;
    wire        W1_LoWrite;
    wire        W1_MemToReg;
    wire [31:0] W1_ALUResult;
    wire [31:0] W1_ReadData;            // Memory read data
    wire [31:0] W1_WriteData;           // Write register data
    wire [(PABITS-8):0] W1_CacheOut;    // Cache operation write data (i/d)
    wire        W1_Mtc0;
    wire        W1_TLBp;
    wire        W1_TLBr;
    wire        W1_TLBwi;
    wire        W1_TLBwr;
    wire [3:0]  W1_TLBIndex;
    wire        W1_ICacheOp;
    wire        W1_ICacheOpEn;
    wire [2:0]  W1_ICacheOpCode;
    wire [(PABITS-11):0] W1_ICacheOpData;
    wire        W1_Eret;
    wire        W1_XOP;
    wire        W1_XOP_Restart;         // Indicator that the upcoming 2nd fetch of an XOP should be skipped
    wire        W1_Tlbp_Hit;
    wire [3:0]  W1_Tlbp_Index;
    wire [(29+(2*PABITS)):0] W1_Tlbr_result;
    wire [1:0]  W1_WriteDataSel;
    wire [31:0] W1_BadVAddr;

    // Local Signals
    reg  reset_r;
    reg  NMI_r;
    wire [9:0]  Current_Hazards;
    wire [63:0] ALU_Mult_Out;
    wire [31:0] ALU_Div_QOut;
    wire [31:0] ALU_Div_ROut;
    wire [31:0] ALU_HiIn;
    wire [31:0] ALU_LoIn;
    wire        ALU_HiWrite;
    wire        ALU_LoWrite;
    wire        ALU_Busy;
    wire        ALU_MulBusy;    // XXX deprecated
    wire        ALU_DivBusy;    // XXX deprecated

    // XXX TODO Check that PFN_Valid goes low on W1 exception. This is how we cancel cache operations.

    //*** Top-level Assignments ***//
    assign InstMem_VAddress      = F1_PC[11:2];
    assign InstMem_PAddress      = F2_PFN;
    assign InstMem_PAddressValid = F2_PFN_Valid & ~W1_Flush;  // F2_Flush includes branch flushes using D2_Issued which is slow
    assign InstMem_CacheAttr     = F2_Cache;
    assign InstMem_Read          = F1_Issued;
    assign InstMem_Stall         = F2_NonMem_Stall;
    assign InstMem_DoCacheOp     = F1_DoICacheOp;
    assign InstMem_CacheOp       = F1_ICacheOp;
    assign InstMem_CacheOpData   = F1_ICacheOpData;
    assign DataMem_VAddress      = M1_ALUResult[11:2];
    assign DataMem_PAddress      = M2_PFN;
    assign DataMem_PAddressValid = M2_PFN_Valid & ~W1_Flush_Pending;  // 2nd term stops new requests prior to a flush
    assign DataMem_CacheAttr     = M2_Cache;
    assign DataMem_Stall         = M2_NonMem_Stall;
    assign DataMem_CacheOp       = M1_RtRd[4:2];
    assign DataMem_CacheOpData   = {W1_CacheOut[(PABITS-8):3], W1_CacheOut[1:0]};

    //*** Pipeline Assignments ***//
    assign F1_Mask_Haz        = reset_r | F1_Stall | F1_Flush;
    assign F1_Mask_Exc        = F1_EXC_AdIF;
    assign F1_Issued          = ~(F1_Mask_Haz | F1_Mask_Exc);
    assign F1_Exception       =  ~F1_Mask_Haz & F1_Mask_Exc;    // i.e., 'AdIF' and no stall/flush/reset
    assign F1_EXC_AdIF        = F1_PC[0] | F1_PC[1];
    assign F1_ExcCode         = (F1_EXC_AdIF) ? `Exc_AdIF : `Exc_None;
    assign F2_Cache_Stall     = F2_F1Issued & ~InstMem_Ready;   // Stall if a request was made and isn't yet ready
    assign F2_Mask_Haz        = F2_Stall | F2_Flush;
    assign F2_Mask_Exc        = F2_EXC_TlbRi | F2_EXC_TlbIi;
    assign F2_Mask_XOP_BL     = F2_F1DoICacheOp | (F2_IsBDS & (D2_XOP_Restart | D2_BDSMask)); // Mask i-cache after 2nd pass to not 'double count'
    assign F2_Issued          = F2_F1Issued & ~(F2_Mask_Haz | F2_Mask_Exc | F2_Mask_XOP_BL);
    assign F2_Exception       = ~F2_Mask_Haz & (F2_F1Exception | (F2_F1Issued & F2_Mask_Exc));
    assign F2_ExcCodes        = {F2_EXC_TlbRi, F2_EXC_TlbIi};
    assign F2_IsBDS           = D2_Issued & D2_NextIsBDS & ~D1_F2Issued;
    generate
        if (`Big_Endian) begin
            assign F2_Instruction = InstMem_In;
        end
        else begin
            assign F2_Instruction = {InstMem_In[7:0], InstMem_In[15:8], InstMem_In[23:16], InstMem_In[31:24]};
        end
    endgenerate
    assign D1_Mask_Haz        = D1_Stall | D1_Flush;
    assign D1_Mask_XOP_BL     = D1_IsBDS & (D2_XOP_Restart | D2_BDSMask);
    assign D1_Issued          = D1_F2Issued & ~(D1_Mask_Haz | D1_Mask_XOP_BL);
    assign D1_Exception       = ~D1_Mask_Haz & D1_F2Exception;
    assign D1_ExcCode         = D1_F2ExcCode;
    assign D1_IsBDS           = D2_Issued & D2_NextIsBDS & D1_F2Issued;
    assign D1_JumpIInst       = (D1_Instruction[31:27] == 5'b00001);  // j, jal
    assign D1_Rs              = D1_Instruction[25:21];
    assign D1_Rt              = D1_Instruction[20:16];
    assign D1_Rd              = D1_Instruction[15:11];
    assign D1_Sel             = D1_Instruction[2:0];
    assign D1_Immediate       = D1_Instruction[15:0];
    assign D1_SignExtImm      = {{14{D1_Immediate[15]}}, D1_Immediate};
    assign D1_SignExtImmShift = {D1_SignExtImm, 2'b00};
    assign D1_JumpRegion      = D1_PCAdd4[31:28];
    assign D1_JumpIAddress    = {D1_JumpRegion, D1_Instruction[25:0], 2'b00};
    assign D1_JumpIBrAddr     = (D1_JumpIInst) ? D1_JumpIAddress : D1_BranchAddress;
    assign D2_Mask_Haz        = D2_Stall | D2_Flush;
    assign D2_Mask_Exc        = |{D2_ExcCodes};
    assign D2_Mask_XOP        = D2_XOP_Restart & ~|{D2_PCSrc_Br};
    assign D2_Issued          = D2_D1Issued & ~(D2_Mask_Haz | D2_Mask_Exc | D2_Mask_XOP);
    assign D2_Exception       = ~D2_Mask_Haz & (D2_D1Exception | (D2_D1Issued & D2_Mask_Exc));
    assign D2_ExcCodes        = {D2_EXC_CpU3, D2_EXC_CpU2, D2_EXC_CpU1, D2_EXC_CpU0, D2_EXC_RI, D2_EXC_Sys, D2_EXC_Bp};
    assign D2_OpCode          = D2_Instruction[31:26];
    assign D2_X1_DP_Hazards   = {D2_DP_Hazards[8:5], D2_DP_Hazards[3:2]};   // XXX cleanup unused bits
    assign D2_Rs              = D2_Instruction[25:21];
    assign D2_Rt              = D2_Instruction[20:16];
    assign D2_Funct           = D2_Instruction[5:0];
    assign D2_SZExtImm        = {{16{D2_SignExtend & D2_Instruction[15]}}, D2_Instruction[15:0]};
    assign D2_Branch          = |{D2_PCSrc_Br} & D2_Issued;
    assign D2_JumpRAddress    = D2_ReadData1_End;
    assign D2_CP0             = |{D2_Mfc0, D2_Mtc0, D2_Eret, D2_TLBp, D2_TLBr, D2_TLBwi, D2_TLBwr, D2_ICacheOp, D2_DCacheOp}; // XXX Are cacheops really considered CP0? Maybe user is fine
    assign X1_Mask_Haz        = X1_Stall | X1_Flush;
    assign X1_Mask_Exc        = X1_EXC_Ov;
    assign X1_Issued          = X1_D2Issued & ~(X1_Mask_Haz | X1_Mask_Exc);
    assign X1_Exception       = ~X1_Mask_Haz & (X1_D2Exception | (X1_D2Issued & X1_Mask_Exc));
    assign X1_M1_DP_Hazards   = X1_DP_Hazards[1:0];
    assign X1_ALUInA          = X1_ReadData1_End;
    assign X1_ALUInB          = X1_ReadData2_End;
    assign X1_WriteData       = X1_ReadData2_Fwd;
    assign X1_Shamt           = X1_SZExtImm[10:6];
    assign X1_RtRd            = X1_RtRd_PreLink | {5{(X1_Link & ~X1_LinkReg)}}; // Set reg 31 for b/jal except jalr.
    assign X1_CP0Sel          = X1_SZExtImm[2:0];
    assign X1_Div             = (X1_ALUOp == `AluOp_Div) | (X1_ALUOp == `AluOp_Divu);
    assign M1_Mask_Haz        = M1_Stall | M1_Flush;
    assign M1_Mask_Exc        = |{M1_ExcCodes};
    assign M1_Issued          = M1_X1Issued & ~(M1_Mask_Haz | M1_Mask_Exc);
    assign M1_Exception       = ~M1_Mask_Haz & (M1_X1Exception | (M1_X1Issued & M1_Mask_Exc));
    assign M1_ExcCodes        = {M1_EXC_AdEL, M1_EXC_AdES, M1_EXC_Tr};
    assign M1_BadVAddr        = (M1_X1Exception) ? M1_X1BadVAddr : M1_ALUResult;
    assign M2_Cache_Stall     = M2_M1Issued & (M2_MemReadIssued | M2_MemWriteIssued) & ~DataMem_Ready & ~M2_Mask_Exc;
    assign M2_Mask_Haz        = M2_Stall | M2_Flush;
    assign M2_Mask_Exc        = |{M2_ExcCodes};
    assign M2_Issued          = M2_M1Issued & ~(M2_Mask_Haz | M2_Mask_Exc);
    assign M2_Exception       = ~M2_Mask_Haz & (M2_M1Exception | (M2_M1Issued & M2_Mask_Exc));
    assign M2_ExcCodes        = {M2_EXC_TlbRLd, M2_EXC_TlbRSd, M2_EXC_TlbILd, M2_EXC_TlbISd, M2_EXC_TlbMd}; // XXX others?
    assign M2_SC              = M2_LLSC & M2_MemWrite;
    assign M2_BadVAddr        = (M2_M1Exception) ? M2_M1BadVAddr : M2_ALUResult;
    assign M2_TLBIndex        = (M2_TLBwr) ? M2_Random_Out : M2_Index_Out;
    assign W1_ExcDetected     = W1_M2Exception | (W1_M2Issued & ~W1_M2MemRWIssued & (Enabled_Int | NMI_r));  // Mask if M2 r/w since Int could come during W1 ALU stall -> too late to cancel
    assign W1_ExcActive       = W1_ExcDetected & ~W1_Stall;
    assign W1_Issued          = W1_M2Issued & ~W1_ExcActive & ~W1_Stall;
    assign W1_WriteDataSel    = {(W1_LoWrite & W1_RegWrite), W1_MemToReg}; // Bit 1 selects 'mul' instruction
    assign W1_ICacheOpEn      = W1_ICacheOp & W1_Issued;
    assign W1_ICacheOpCode    = W1_RtRd[4:2];
    assign W1_ICacheOpData    = {W1_CacheOut[(PABITS-8):5], W1_CacheOut[1:0]};
    assign W1_XOP_Restart     = W1_XOP & W1_Issued & ~W1_Eret;  // Eret already jumps to the next PC


    // F2 Exception Code
    always @(*) begin
        if (F2_F1Exception) begin
            F2_ExcCode = F2_F1ExcCode;
        end
        else begin
            case (F2_ExcCodes)
                2'b10:      F2_ExcCode = `Exc_TlbRi;
                2'b01:      F2_ExcCode = `Exc_TlbIi;
                default:    F2_ExcCode = `Exc_None;
            endcase
        end
    end

    // D2 Exception Code
    always @(*) begin
        if (D2_D1Exception) begin
            D2_ExcCode = D2_D1ExcCode;
        end
        else begin
            case (D2_ExcCodes)
                7'b1000000: D2_ExcCode = `Exc_CpU3;
                7'b0100000: D2_ExcCode = `Exc_CpU2;
                7'b0010000: D2_ExcCode = `Exc_CpU1;
                7'b0001000: D2_ExcCode = `Exc_CpU0;
                7'b0000100: D2_ExcCode = `Exc_RI;
                7'b0000010: D2_ExcCode = `Exc_Sys;
                7'b0000001: D2_ExcCode = `Exc_Bp;
                default:    D2_ExcCode = `Exc_None;
            endcase
        end
    end

    // X1 Exception Code
    always @(*) begin
        if (X1_D2Exception) begin
            X1_ExcCode = X1_D2ExcCode;
        end
        else begin
            case (X1_EXC_Ov)
                1'b1:       X1_ExcCode = `Exc_Ov;
                default:    X1_ExcCode = `Exc_None;
            endcase
        end
    end

    // M1 Exception Code
    always @(*) begin
        if (M1_X1Exception) begin
            M1_ExcCode = M1_X1ExcCode;
        end
        else begin
            case (M1_ExcCodes)
                3'b100:    M1_ExcCode = `Exc_AdEL;
                3'b010:    M1_ExcCode = `Exc_AdES;
                3'b001:    M1_ExcCode = `Exc_Tr;
                default:   M1_ExcCode = `Exc_None;
            endcase
        end
    end

    // M2 Exception Code
    always @(*) begin
        if (M2_M1Exception) begin
            M2_ExcCode = M2_M1ExcCode;
        end
        else begin
            case (M2_ExcCodes)
                5'b10000:   M2_ExcCode = `Exc_TlbRLd;
                5'b01000:   M2_ExcCode = `Exc_TlbRSd;
                5'b00100:   M2_ExcCode = `Exc_TlbILd;
                5'b00010:   M2_ExcCode = `Exc_TlbISd;
                5'b00001:   M2_ExcCode = `Exc_TlbMd;
                default:    M2_ExcCode = `Exc_None;
            endcase
        end
    end

    // W1 Exception Code
    always @(*) begin
        if (W1_ExcActive) begin
            W1_ExcCode = (Enabled_Int) ? `Exc_Int : W1_M2ExcCode;
        end
        else begin
            W1_ExcCode = `Exc_None;
        end
    end

    // Registered Reset
    always @(posedge clock) begin
        reset_r <= reset;
    end

    // Registered NMI
    always @(posedge clock) begin
        NMI_r <= NMI;
    end

    //*** Local Assignments ***//
    assign Current_Hazards = {D2_DP_Hazards[12:9], X1_DP_Hazards[5:2], M1_DP_Hazards[1:0]};
    assign ALU_HiIn    = (W1_HiWrite ^ W1_LoWrite) ? W1_WriteData : (W1_Div) ? ALU_Div_ROut : ALU_Mult_Out[63:32];
    assign ALU_LoIn    = (W1_HiWrite ^ W1_LoWrite) ? W1_WriteData : (W1_Div) ? ALU_Div_QOut : ALU_Mult_Out[31:0];
    assign ALU_HiWrite = W1_Issued & W1_HiWrite;
    assign ALU_LoWrite = W1_Issued & W1_LoWrite;
    assign ALU_MulBusy = ALU_Busy;  // XXX TODO combine mult/div. We only care about busy.
    assign ALU_DivBusy = ALU_Busy;

    //*** Instruction Fetch Stage 1 Register ***//
    F1_Stage #(.PABITS(PABITS)) F1 (
        .clock            (clock),
        .reset            (reset),
        .F1_Stall         (F1_Stall),
        .F1_Flush         (F1_Flush),
        .D2_PC            (D2_PC),
        .W1_DoICacheOp    (W1_ICacheOpEn),
        .W1_ICacheOp      (W1_ICacheOpCode),
        .W1_ICacheOpData  (W1_ICacheOpData),
        .W1_XOP_Restart   (W1_XOP_Restart),
        .F1_PC            (F1_PC),
        .F1_DoICacheOp    (F1_DoICacheOp),
        .F1_ICacheOp      (F1_ICacheOp),
        .F1_ICacheOpData  (F1_ICacheOpData),
        .F1_XOP_Restart   (F1_XOP_Restart)
    );

    //*** PC+4 Adder ***//
    Add #(.WIDTH(32)) PC_Add4 (
        .A  (F1_PC),
        .B  (32'd4),
        .C  (F1_PCAdd4)
    );

    //*** PC+4 / Restart Instruction Mux ***//
    Mux2 #(.WIDTH(32)) PCXOP_Mux (
        .sel (W1_XOP_Restart | F1_DoICacheOp),  // Regular XOPs and i-cache 2nd-cycle
        .in0 (F1_PCAdd4),
        .in1 (W1_RestartPC),
        .out (F1_PCAdd4_XOP)
    );

    //*** Instruction Fetch Stage 2 Register ***//
    F2_Stage F2 (
        .clock           (clock),
        .reset           (reset),
        .F1_Issued       (F1_Issued),
        .F1_Exception    (F1_Exception),
        .F1_ExcCode      (F1_ExcCode),
        .F2_Stall        (F2_Stall),
        .F2_Flush        (F2_Flush),
        .F1_PC           ((F1_DoICacheOp) ? W1_RestartPC : F1_PC),  // Allow i-cache op exceptions
        .F1_DoICacheOp   (F1_DoICacheOp),
        .F1_PCAdd4       (F1_PCAdd4_XOP),
        .F1_XOP_Restart  (F1_XOP_Restart),
        .F2_F1Issued     (F2_F1Issued),
        .F2_FetchPC      (F2_FetchPC),
        .F2_PCAdd4       (F2_PCAdd4),
        .F2_F1Exception  (F2_F1Exception),
        .F2_F1ExcCode    (F2_F1ExcCode),
        .F2_F1DoICacheOp (F2_F1DoICacheOp),
        .F2_XOP_Restart  (F2_XOP_Restart)
    );

    //*** Instruction Decode Stage 1 Register ***//
    D1_Stage D1 (
        .clock           (clock),
        .reset           (reset),
        .F2_Issued       (F2_Issued),
        .F2_Exception    (F2_Exception),
        .F2_ExcCode      (F2_ExcCode),
        .D1_Stall        (D1_Stall),
        .D1_Flush        (D1_Flush),
        .F2_IsBDS        (F2_IsBDS),
        .F2_Instruction  (F2_Instruction),
        .F2_FetchPC      (F2_FetchPC),
        .F2_PCAdd4       (F2_PCAdd4),
        .F2_XOP_Restart  (F2_XOP_Restart),
        .D1_F2Issued     (D1_F2Issued),
        .D1_Instruction  (D1_Instruction),
        .D1_FetchPC      (D1_FetchPC),
        .D1_F2IsBDS      (D1_F2IsBDS),
        .D1_PCAdd4       (D1_PCAdd4),
        .D1_F2Exception  (D1_F2Exception),
        .D1_F2ExcCode    (D1_F2ExcCode),
        .D1_XOP_Restart  (D1_XOP_Restart)
    );

    //*** Branch Address Adder ***//
    Add #(.WIDTH(32)) BranchAddress_Add (
        .A  (D1_PCAdd4),
        .B  (D1_SignExtImmShift),
        .C  (D1_BranchAddress)
    );

    //*** Register File ***//
    RegisterFile RegisterFile (
        .clock        (clock),
        .ReadReg1     (D1_Rs),
        .ReadReg2     (D1_Rt),
        .WriteReg     (W1_RtRd),
        .WriteData    (W1_WriteData),
        .WriteEnable  ((W1_RegWrite & W1_Issued)),
        .ReadData1    (D1_ReadData1),
        .ReadData2    (D1_ReadData2)
    );

    //*** D1 Read Data 1 (Rs) Forward Mux ***//
    Mux2 #(.WIDTH(32)) D1ReadData1_FwdMux (
        .sel  (D1_RsFwdSel),
        .in0  (D1_ReadData1),
        .in1  (W1_WriteData),
        .out  (D1_ReadData1_End)
    );

    //*** D2 Read Data 2 (Rt) Forward Mux ***//
    Mux2 #(.WIDTH(32)) D1ReadData2_FwdMux (
        .sel  (D1_RtFwdSel),
        .in0  (D1_ReadData2),
        .in1  (W1_WriteData),
        .out  (D1_ReadData2_End)
    );

    //*** Instruction Decode Stage 2 Register ***//
    D2_Stage D2 (
        .clock             (clock),
        .reset             (reset),
        .D1_Issued         (D1_Issued),
        .D1_Exception      (D1_Exception),
        .D1_ExcCode        (D1_ExcCode),
        .D2_Stall          (D2_Stall),
        .D2_Flush          (D2_Flush),
        .D1_IsBDS          (D1_IsBDS),
        .D1_F2IsBDS        (D1_F2IsBDS),
        .D1_Instruction    (D1_Instruction),
        .D1_FetchPC        (D1_FetchPC),
        .D1_ReadData1      (D1_ReadData1_End),
        .D1_ReadData2      (D1_ReadData2_End),
        .D2_ReadData1_Fwd  (D2_ReadData1_End),
        .D2_ReadData2_Fwd  (D2_ReadData2_End),
        .D1_Cp0_ReadData   (D1_Cp0_ReadData),
        .D1_XOP_Restart    (D1_XOP_Restart),
        .D1_JumpIBrAddr    (D1_JumpIBrAddr),
        .D2_D1Issued       (D2_D1Issued),
        .D2_Instruction    (D2_Instruction),
        .D2_RestartPC      (D2_RestartPC),
        .D2_IsBDS          (D2_IsBDS),
        .D2_ReadData1      (D2_ReadData1),
        .D2_ReadData2      (D2_ReadData2),
        .D2_Cp0_ReadData   (D2_Cp0_ReadData),
        .D2_D1Exception    (D2_D1Exception),
        .D2_D1ExcCode      (D2_D1ExcCode),
        .D2_BadVAddr       (D2_BadVAddr),
        .D2_XOP_Restart    (D2_XOP_Restart),
        .D2_JumpIBrAddr    (D2_JumpIBrAddr)
    );

    // PC Source: Exceptions have priority. After that, non-branch/jumps and flushes get
    // PC+4 / XOP RestartPC, branches and immediate jumps get JumpIBrAddr, and register jumps
    // get the post-forwarded register data. An i-cache operation is a special serialized (XOP)
    // case that always gets an effective address from the W1 ALU result.
    assign D2_PCSrc_Sel[1] = D2_PCSrc_Exc | (D2_Issued & (D2_PCSrc_Br[1] & D2_PCSrc_Br[0])) | W1_ICacheOpEn;
    assign D2_PCSrc_Sel[0] = D2_PCSrc_Exc | (D2_Issued & (D2_PCSrc_Br[1] ^ D2_PCSrc_Br[0])) & ~W1_ICacheOpEn;

    // *** PC Source Final Mux *** //
    Mux4 #(.WIDTH(32)) PCSrc_Mux (
        .sel  (D2_PCSrc_Sel),
        .in0  (F1_PCAdd4_XOP),
        .in1  (D2_JumpIBrAddr),
        .in2  (D2_JumpRAddress),
        .in3  (D2_ExceptionPC),
        .out  (D2_PC)
    );

    //*** D2 Read Data 1 (Rs) CP0 Mux ***//
    Mux2 #(.WIDTH(32)) D2ReadData1_Cp0Mux (
        .sel  (D2_Mfc0),
        .in0  (D2_ReadData1),
        .in1  (D2_Cp0_ReadData),
        .out  (D2_ReadData1_Cp0)
    );

    //*** D2 Read Data 1 (Rs) Forward Mux ***//
    Mux4 #(.WIDTH(32)) D2ReadData1_FwdMux (
        .sel  (D2_RsFwdSel),
        .in0  (D2_ReadData1_Cp0),
        .in1  (M1_ALUResult),
        .in2  (M2_ALUResult),
        .in3  (W1_WriteData),
        .out  (D2_ReadData1_End)
    );

    //*** D2 Read Data 2 (Rt) Link Mux ***//
    Mux2 #(.WIDTH(32)) D2ReadData2_LinkMux (
        .sel  (D2_Link),
        .in0  (D2_ReadData2),
        .in1  (D2_RestartPC),
        .out  (D2_ReadData2_Link)
    );

    //*** D2 Read Data 2 (Rt) Forward Mux ***//
    Mux4 #(.WIDTH(32)) D2ReadData2_FwdMux (
        .sel  (D2_RtFwdSel),
        .in0  (D2_ReadData2_Link),
        .in1  (M1_ALUResult),
        .in2  (M2_ALUResult),
        .in3  (W1_WriteData),
        .out  (D2_ReadData2_End)
    );

    //*** Datapath Controller ***//
    Control Control (
        .OpCode         (D2_OpCode),
        .Funct          (D2_Funct),
        .Rs             (D2_Rs),
        .Rt             (D2_Rt),
        .RsData         (D2_ReadData1_End),
        .RtData         (D2_ReadData2_End),
        .PCSrc          (D2_PCSrc_Br),
        .NextIsBDS      (D2_NextIsBDS),
        .BDSMask        (D2_BDSMask),
        .ALUSrcImm      (D2_ALUSrcImm),
        .Movn           (D2_Movn),
        .Movz           (D2_Movz),
        .Trap           (D2_Trap),
        .TrapCond       (D2_TrapCond),
        .RegDst         (D2_RegDst),
        .LLSC           (D2_LLSC),
        .MemRead        (D2_MemRead),
        .MemWrite       (D2_MemWrite),
        .MemHalf        (D2_MemHalf),
        .MemByte        (D2_MemByte),
        .MemSignExtend  (D2_MemSignExtend),
        .RegWrite       (D2_RegWrite),
        .HiRead         (D2_HiRead),
        .LoRead         (D2_LoRead),
        .HiWrite        (D2_HiWrite),
        .LoWrite        (D2_LoWrite),
        .MemToReg       (D2_MemToReg),
        .DP_Hazards     (D2_DP_Hazards),
        .Left           (D2_Left),
        .Right          (D2_Right),
        .SignExtend     (D2_SignExtend),
        .Link           (D2_Link),
        .LinkReg        (D2_LinkReg),
        .ALUOp          (D2_ALUOp),
        .XOP            (D2_XOP),
        .Mfc0           (D2_Mfc0),
        .Mtc0           (D2_Mtc0),
        .Eret           (D2_Eret),
        .TLBp           (D2_TLBp),
        .TLBr           (D2_TLBr),
        .TLBwi          (D2_TLBwi),
        .TLBwr          (D2_TLBwr),
        .ICacheOp       (D2_ICacheOp),
        .DCacheOp       (D2_DCacheOp),
        .CP1            (D2_CP1),
        .CP2            (D2_CP2),
        .CP3            (D2_CP3),
        .EXC_Bp         (D2_EXC_Bp),
        .EXC_Sys        (D2_EXC_Sys),
        .EXC_RI         (D2_EXC_RI)
    );

    //*** Hazard Unit ***//
    Hazard_Detection Hazards (
        .DP_Hazards        (Current_Hazards),
        .D1_F2Issued       (D1_F2Issued),
        .D2_D1Issued       (D2_D1Issued),
        .X1_D2Issued       (X1_D2Issued),
        .M1_X1Issued       (M1_X1Issued),
        .M2_M1Issued       (M2_M1Issued),
        .W1_M2Issued       (W1_M2Issued),
        .D1_Rs             (D1_Rs),
        .D1_Rt             (D1_Rt),
        .D2_Rs             (D2_Rs),
        .D2_Rt             (D2_Rt),
        .X1_Rs             (X1_Rs),
        .X1_Rt             (X1_Rt),
        .M1_Rt             (M1_Rt),
        .X1_RtRd           (X1_RtRd),
        .M1_RtRd           (M1_RtRd),
        .M2_RtRd           (M2_RtRd),
        .W1_RtRd           (W1_RtRd),
        .X1_RegWrite       (X1_RegWrite),
        .M1_RegWrite       (M1_RegWrite),
        .M2_RegWrite       (M2_RegWrite),
        .W1_RegWrite       (W1_RegWrite),
        .M1_MemRead        (M1_MemRead),
        .M1_MemWrite       (M1_MemWrite),
        .M2_MemRead        (M2_MemRead),
        .M2_MemWrite       (M2_MemWrite),
        .X1_HiLoRead       ((X1_HiRead  | X1_LoRead)),
        .M1_HiLoWrite      ((M1_HiWrite | M1_LoWrite)),
        .M2_HiLoWrite      ((M2_HiWrite | M2_LoWrite)),
        .W1_HiLoWrite      ((W1_HiWrite | W1_LoWrite)),
        .W1_XOP            (W1_XOP),
        .F2_Cache_Stall    (F2_Cache_Stall),
        .F2_Cache_Blocked  (InstMem_Blocked),
        .M2_Cache_Stall    (M2_Cache_Stall),
        .D2_NextIsBDS      (D2_NextIsBDS),
        .D2_Branch         (D2_Branch),
        .ALU_MulBusy       (ALU_MulBusy),
        .ALU_DivBusy       (ALU_DivBusy),
        .W1_ExcDetected    (W1_ExcDetected),
        .W1_ICacheOpEn     (W1_ICacheOpEn),
        .D1_RsFwdSel       (D1_RsFwdSel),
        .D1_RtFwdSel       (D1_RtFwdSel),
        .D2_RsFwdSel       (D2_RsFwdSel),
        .D2_RtFwdSel       (D2_RtFwdSel),
        .X1_RsFwdSel       (X1_RsFwdSel),
        .X1_RtFwdSel       (X1_RtFwdSel),
        .M1_RtFwdSel       (M1_RtFwdSel),
        .F1_Stall          (F1_Stall),
        .F2_NonMem_Stall   (F2_NonMem_Stall),
        .F2_Stall          (F2_Stall),
        .D1_Stall          (D1_Stall),
        .D2_Stall          (D2_Stall),
        .X1_Stall          (X1_Stall),
        .M1_Stall          (M1_Stall),
        .M2_NonMem_Stall   (M2_NonMem_Stall),
        .M2_Stall          (M2_Stall),
        .W1_NonMem_Stall   (W1_NonMem_Stall),
        .W1_Stall          (W1_Stall),
        .F1_Flush          (F1_Flush),
        .F2_Flush          (F2_Flush),
        .D1_Flush          (D1_Flush),
        .D2_Flush          (D2_Flush),
        .X1_Flush          (X1_Flush),
        .M1_Flush          (M1_Flush),
        .M2_Flush          (M2_Flush),
        .W1_Flush_Pending  (W1_Flush_Pending),
        .W1_Flush          (W1_Flush)
    );

    //*** Coprocessor 0 ***//
    CPZero #(.PABITS(PABITS)) CP0 (
        .clock              (clock),
        .reset              (reset),
        .reset_r            (reset_r),
        .W1_Issued          (W1_Issued),
        .W1_Reg_In          (W1_WriteData),
        .F2_Stall           (F2_Stall),
        .M2_Stall           (M2_Cache_Stall | W1_NonMem_Stall), // 'M2_Stall' is more complex; this skips W1 waiting on caches due to exceptions
        .D1_Rd              (D1_Rd),
        .D1_Sel             (D1_Sel),
        .D1_Reg_Out         (D1_Cp0_ReadData),
        .W1_Rd              (W1_RtRd),
        .W1_Sel             (W1_CP0Sel),
        .W1_Mtc0            (W1_Mtc0),
        .F1_VPN             (F1_PC[31:12]),
        .M1_VPN             (M1_ALUResult[31:12]),
        .F2_TLB_L           (F2_F1Issued),
        .M2_TLB_L           (M2_MemReadIssued),
        .M2_TLB_S           (M2_MemWriteIssued),
        .F2_PFN             (F2_PFN),
        .M2_PFN             (M2_PFN),
        .F2_Cache           (F2_Cache),
        .M2_Cache           (M2_Cache),
        .F2_PFN_Valid       (F2_PFN_Valid),
        .M2_PFN_Valid       (M2_PFN_Valid),
        .M1_Tlbp            (M1_TLBp),
        .M1_Tlbr            (M1_TLBr),
        .W1_Tlbp            (W1_TLBp),
        .W1_Tlbr            (W1_TLBr),
        .W1_Tlbwi           (W1_TLBwi),
        .W1_Tlbwr           (W1_TLBwr),
        .M2_Tlbp_Hit        (M2_Tlbp_Hit),
        .M2_Tlbp_Index      (M2_Tlbp_Index),
        .W1_Tlbp_Hit        (W1_Tlbp_Hit),
        .W1_Tlbp_Index      (W1_Tlbp_Index),
        .M2_Tlbr_result     (M2_Tlbr_result),
        .W1_Tlbr_result     (W1_Tlbr_result),
        .W1_TLBIndex        (W1_TLBIndex),
        .Int                (Interrupts),
        .NMI                (NMI_r),
        .D2_COP0            (D2_CP0),
        .D2_COP1            (D2_CP1),
        .D2_COP2            (D2_CP2),
        .D2_COP3            (D2_CP3),
        .F2_EXC_TlbRi       (F2_EXC_TlbRi),
        .F2_EXC_TlbIi       (F2_EXC_TlbIi),
        .D2_EXC_CpU0        (D2_EXC_CpU0),
        .D2_EXC_CpU1        (D2_EXC_CpU1),
        .D2_EXC_CpU2        (D2_EXC_CpU2),
        .D2_EXC_CpU3        (D2_EXC_CpU3),
        .M2_EXC_TlbRLd      (M2_EXC_TlbRLd),
        .M2_EXC_TlbRSd      (M2_EXC_TlbRSd),
        .M2_EXC_TlbILd      (M2_EXC_TlbILd),
        .M2_EXC_TlbISd      (M2_EXC_TlbISd),
        .M2_EXC_TlbMd       (M2_EXC_TlbMd),
        .Enabled_Int        (Enabled_Int),
        .W1_ExcActive       (W1_ExcActive),
        .W1_ExcCode         (W1_ExcCode),
        .W1_ExcVAddr        (W1_BadVAddr),
        .W1_ExcRestartPC    (W1_RestartPC),
        .W1_ExcIsBDS        (W1_IsBDS),
        .W1_Eret            (W1_Eret),
        .D2_Exc_PC_Sel      (D2_PCSrc_Exc),
        .D2_Exc_PC_Out      (D2_ExceptionPC),
        .Cache_Out          (W1_CacheOut),
        .Index_Out          (M2_Index_Out),
        .Random_Out         (M2_Random_Out),
        .M1_ReverseEndian   (M1_ReverseEndian),
        .M1_KernelMode      (M1_KernelMode)
    );

    //*** Execute Stage Register ***//
    X1_Stage X1 (
        .clock             (clock),
        .reset             (reset),
        .D2_Issued         (D2_Issued),
        .D2_Exception      (D2_Exception),
        .D2_ExcCode        (D2_ExcCode),
        .X1_Stall          (X1_Stall),
        .X1_Flush          (X1_Flush),
        .D2_RestartPC      (D2_RestartPC),
        .D2_IsBDS          (D2_IsBDS),
        .D2_X1_DP_Hazards  (D2_X1_DP_Hazards),
        .D2_Rs             (D2_Rs),
        .D2_Rt             (D2_Rt),
        .D2_ReadData1      (D2_ReadData1_End),
        .D2_ReadData2      (D2_ReadData2_End),
        .X1_ReadData1_Fwd  (X1_ReadData1_End),
        .X1_ReadData2_Fwd  (X1_ReadData2_Fwd),
        .D2_SZExtImm       (D2_SZExtImm),
        .D2_ALUSrcImm      (D2_ALUSrcImm),
        .D2_Movn           (D2_Movn),
        .D2_Movz           (D2_Movz),
        .D2_Trap           (D2_Trap),
        .D2_TrapCond       (D2_TrapCond),
        .D2_RegDst         (D2_RegDst),
        .D2_LLSC           (D2_LLSC),
        .D2_MemRead        (D2_MemRead),
        .D2_MemWrite       (D2_MemWrite),
        .D2_MemHalf        (D2_MemHalf),
        .D2_MemByte        (D2_MemByte),
        .D2_Left           (D2_Left),
        .D2_Right          (D2_Right),
        .D2_MemSignExtend  (D2_MemSignExtend),
        .D2_Link           (D2_Link),
        .D2_LinkReg        (D2_LinkReg),
        .D2_RegWrite       (D2_RegWrite),
        .D2_HiRead         (D2_HiRead),
        .D2_LoRead         (D2_LoRead),
        .D2_HiWrite        (D2_HiWrite),
        .D2_LoWrite        (D2_LoWrite),
        .D2_MemToReg       (D2_MemToReg),
        .D2_ALUOp          (D2_ALUOp),
        .D2_Eret           (D2_Eret),
        .D2_XOP            (D2_XOP),
        .D2_Mtc0           (D2_Mtc0),
        .D2_TLBp           (D2_TLBp),
        .D2_TLBr           (D2_TLBr),
        .D2_TLBwi          (D2_TLBwi),
        .D2_TLBwr          (D2_TLBwr),
        .D2_ICacheOp       (D2_ICacheOp),
        .D2_DCacheOp       (D2_DCacheOp),
        .D2_BadVAddr       (D2_BadVAddr),
        .X1_D2Issued       (X1_D2Issued),
        .X1_D2Exception    (X1_D2Exception),
        .X1_D2ExcCode      (X1_D2ExcCode),
        .X1_RestartPC      (X1_RestartPC),
        .X1_IsBDS          (X1_IsBDS),
        .X1_DP_Hazards     (X1_DP_Hazards),
        .X1_Rs             (X1_Rs),
        .X1_Rt             (X1_Rt),
        .X1_ReadData1      (X1_ReadData1),
        .X1_ReadData2      (X1_ReadData2),
        .X1_SZExtImm       (X1_SZExtImm),
        .X1_ALUSrcImm      (X1_ALUSrcImm),
        .X1_Movn           (X1_Movn),
        .X1_Movz           (X1_Movz),
        .X1_Trap           (X1_Trap),
        .X1_TrapCond       (X1_TrapCond),
        .X1_RegDst         (X1_RegDst),
        .X1_LLSC           (X1_LLSC),
        .X1_MemRead        (X1_MemRead),
        .X1_MemWrite       (X1_MemWrite),
        .X1_MemHalf        (X1_MemHalf),
        .X1_MemByte        (X1_MemByte),
        .X1_Left           (X1_Left),
        .X1_Right          (X1_Right),
        .X1_MemSignExtend  (X1_MemSignExtend),
        .X1_Link           (X1_Link),
        .X1_LinkReg        (X1_LinkReg),
        .X1_RegWrite       (X1_RegWrite),
        .X1_HiRead         (X1_HiRead),
        .X1_LoRead         (X1_LoRead),
        .X1_HiWrite        (X1_HiWrite),
        .X1_LoWrite        (X1_LoWrite),
        .X1_MemToReg       (X1_MemToReg),
        .X1_ALUOp          (X1_ALUOp),
        .X1_Mtc0           (X1_Mtc0),
        .X1_TLBp           (X1_TLBp),
        .X1_TLBr           (X1_TLBr),
        .X1_TLBwi          (X1_TLBwi),
        .X1_TLBwr          (X1_TLBwr),
        .X1_ICacheOp       (X1_ICacheOp),
        .X1_DCacheOp       (X1_DCacheOp),
        .X1_Eret           (X1_Eret),
        .X1_XOP            (X1_XOP),
        .X1_BadVAddr       (X1_BadVAddr)
    );

    //*** X1 Read Data 1 (Rs) Link Mux ***//
    Mux2 #(.WIDTH(32)) X1ReadData1_LinkMux (
        .sel  (X1_Link),
        .in0  (X1_ReadData1),
        .in1  (32'h8),
        .out  (X1_ReadData1_Link)
    );

    //*** X1 Read Data 1 (Rs) Forward Mux ***//
    Mux4 #(.WIDTH(32)) X1ReadData1_FwdMux (
        .sel  (X1_RsFwdSel),
        .in0  (X1_ReadData1_Link),
        .in1  (M1_ALUResult),
        .in2  (M2_ALUResult),
        .in3  (W1_WriteData),
        .out  (X1_ReadData1_End)
    );

    //*** X1 Read Data 2 (Rt) Fwd Mux ***//
    Mux4 #(.WIDTH(32)) X1RtFwd_Mux (
        .sel  (X1_RtFwdSel),
        .in0  (X1_ReadData2),
        .in1  (M1_ALUResult),
        .in2  (M2_ALUResult),
        .in3  (W1_WriteData),
        .out  (X1_ReadData2_Fwd)
    );

    //*** X1 ALU Immediate Mux ***//
    Mux2 #(.WIDTH(32)) X1ALUImm_Mux (
        .sel  (X1_ALUSrcImm),
        .in0  (X1_ReadData2_Fwd),
        .in1  (X1_SZExtImm),
        .out  (X1_ReadData2_End)
    );

    //*** X1 Write Register Destination Mux ***//
    Mux2 #(.WIDTH(5)) X1RegDst_Mux (
        .sel  (X1_RegDst),
        .in0  (X1_Rt),
        .in1  (X1_SZExtImm[15:11]),
        .out  (X1_RtRd_PreLink)
    );

    //*** Arithmetic Logic Unit (ALU) ***//
    ALU ALU (
        .clock         (clock),
        .reset         (reset),
        .X1_Issued     (X1_Issued),
        .X1_HiLoWrite  ((X1_HiWrite | X1_LoWrite)),
        .A             (X1_ALUInA),
        .B             (X1_ALUInB),
        .Operation     (X1_ALUOp),
        .Shamt         (X1_Shamt),
        .HiIn          (ALU_HiIn),
        .LoIn          (ALU_LoIn),
        .HiWrite       (ALU_HiWrite),
        .LoWrite       (ALU_LoWrite),
        .Result        (X1_ALUResult),
        .EXC_Ov        (X1_EXC_Ov),
        .BZero         (X1_BZero),
        .ALU_Busy      (ALU_Busy),
        .Mult_Out      (ALU_Mult_Out),
        .Div_QOut      (ALU_Div_QOut),
        .Div_ROut      (ALU_Div_ROut)
    );

    //*** Memory Stage 1 Register ***//
    M1_Stage M1 (
        .clock             (clock),
        .reset             (reset),
        .X1_Issued         (X1_Issued),
        .X1_Exception      (X1_Exception),
        .X1_ExcCode        (X1_ExcCode),
        .M1_Stall          (M1_Stall),
        .M1_Flush          (M1_Flush),
        .X1_RestartPC      (X1_RestartPC),
        .X1_IsBDS          (X1_IsBDS),
        .X1_M1_DP_Hazards  (X1_M1_DP_Hazards),
        .X1_Rt             (X1_Rt),
        .X1_RtRd           (X1_RtRd),
        .X1_CP0Sel         (X1_CP0Sel),
        .X1_Movn           (X1_Movn),
        .X1_Movz           (X1_Movz),
        .X1_BZero          (X1_BZero),
        .X1_Trap           (X1_Trap),
        .X1_TrapCond       (X1_TrapCond),
        .X1_LLSC           (X1_LLSC),
        .X1_MemRead        (X1_MemRead),
        .X1_MemWrite       (X1_MemWrite),
        .X1_MemHalf        (X1_MemHalf),
        .X1_MemByte        (X1_MemByte),
        .X1_Left           (X1_Left),
        .X1_Right          (X1_Right),
        .X1_MemSignExtend  (X1_MemSignExtend),
        .X1_Div            (X1_Div),
        .X1_RegWrite       (X1_RegWrite),
        .X1_HiWrite        (X1_HiWrite),
        .X1_LoWrite        (X1_LoWrite),
        .X1_MemToReg       (X1_MemToReg),
        .X1_ALUResult      (X1_ALUResult),
        .X1_WriteData      (X1_WriteData),
        .X1_BadVAddr       (X1_BadVAddr),
        .M1_WriteData_Fwd  (M1_WriteData_End),
        .X1_Mtc0           (X1_Mtc0),
        .X1_TLBp           (X1_TLBp),
        .X1_TLBr           (X1_TLBr),
        .X1_TLBwi          (X1_TLBwi),
        .X1_TLBwr          (X1_TLBwr),
        .X1_ICacheOp       (X1_ICacheOp),
        .X1_DCacheOp       (X1_DCacheOp),
        .X1_Eret           (X1_Eret),
        .X1_XOP            (X1_XOP),
        .M1_X1Issued       (M1_X1Issued),
        .M1_X1Exception    (M1_X1Exception),
        .M1_X1ExcCode      (M1_X1ExcCode),
        .M1_RestartPC      (M1_RestartPC),
        .M1_IsBDS          (M1_IsBDS),
        .M1_DP_Hazards     (M1_DP_Hazards),
        .M1_Rt             (M1_Rt),
        .M1_RtRd           (M1_RtRd),
        .M1_CP0Sel         (M1_CP0Sel),
        .M1_Trap           (M1_Trap),
        .M1_TrapCond       (M1_TrapCond),
        .M1_LLSC           (M1_LLSC),
        .M1_MemRead        (M1_MemRead),
        .M1_MemWrite       (M1_MemWrite),
        .M1_MemHalf        (M1_MemHalf),
        .M1_MemByte        (M1_MemByte),
        .M1_Left           (M1_Left),
        .M1_Right          (M1_Right),
        .M1_MemSignExtend  (M1_MemSignExtend),
        .M1_Div            (M1_Div),
        .M1_RegWrite       (M1_RegWrite),
        .M1_HiWrite        (M1_HiWrite),
        .M1_LoWrite        (M1_LoWrite),
        .M1_MemToReg       (M1_MemToReg),
        .M1_ALUResult      (M1_ALUResult),
        .M1_WriteData      (M1_WriteData),
        .M1_Mtc0           (M1_Mtc0),
        .M1_TLBp           (M1_TLBp),
        .M1_TLBr           (M1_TLBr),
        .M1_TLBwi          (M1_TLBwi),
        .M1_TLBwr          (M1_TLBwr),
        .M1_ICacheOp       (M1_ICacheOp),
        .M1_DCacheOp       (M1_DCacheOp),
        .M1_Eret           (M1_Eret),
        .M1_XOP            (M1_XOP),
        .M1_BadVAddr       (M1_X1BadVAddr)
    );

    //*** Trap Detection ***//
    TrapDetect TrapDetect (
        .Trap      (M1_Trap),
        .TrapCond  (M1_TrapCond),
        .ALUResult (M1_ALUResult),
        .EXC_Tr    (M1_EXC_Tr)
    );

    //*** M1 Write Data Forward Mux ***//
    Mux4 #(.WIDTH(32)) M1WriteData_FwdMux (
        .sel  (M1_RtFwdSel),
        .in0  (M1_WriteData),
        .in1  (M2_ALUResult),
        .in2  (W1_WriteData),
        .in3  ({32{1'bx}}),
        .out  (M1_WriteData_End)
    );

    //*** Memory Control Unit ***//
    MemControl MemControl (
        .clock               (clock),
        .reset               (reset),
        .M1_Issued           (M1_Issued),
        .DataIn              (M1_WriteData_End),
        .Address             (M1_ALUResult[31:0]),
        .Read                (M1_MemRead),
        .Write               (M1_MemWrite),
        .Byte                (M1_MemByte),
        .Half                (M1_MemHalf),
        .Left                (M1_Left),
        .Right               (M1_Right),
        .LLSC                (M1_LLSC),
        .ICacheOp            (M1_ICacheOp),
        .DCacheOp            (M1_DCacheOp),
        .Eret                (M1_Eret),            // No pipeline races but may have false positives (e.g. non-issued)
        .ReverseEndian       (M1_ReverseEndian),
        .KernelMode          (M1_KernelMode),
        .Mem_WriteData       (DataMem_Out),
        .Mem_WriteEnable     (DataMem_Write),
        .Mem_ReadEnable      (DataMem_Read),
        .Mem_DCacheOpEnable  (DataMem_DoCacheOp),
        .EXC_AdEL            (M1_EXC_AdEL),
        .EXC_AdES            (M1_EXC_AdES),
        .M_BigEndian         (M1_BigEndian),
        .M2_Atomic           (M2_Atomic)
    );

    //*** Memory Stage 2 Register ***//
    M2_Stage M2 (
        .clock             (clock),
        .reset             (reset),
        .M1_Issued         (M1_Issued),
        .M1_Exception      (M1_Exception),
        .M1_ExcCode        (M1_ExcCode),
        .M2_Stall          (M2_Stall),
        .M2_Flush          (M2_Flush),
        .M1_RestartPC      (M1_RestartPC),
        .M1_IsBDS          (M1_IsBDS),
        .M1_RtRd           (M1_RtRd),
        .M1_CP0Sel         (M1_CP0Sel),
        .M1_LLSC           (M1_LLSC),
        .M1_MemRead        (M1_MemRead),
        .M1_MemReadIssued  (DataMem_Read | DataMem_DoCacheOp),  // XXX clean up
        .M1_MemWrite       (M1_MemWrite),
        .M1_MemWriteIssued (|{DataMem_Write}),
        .M1_MemHalf        (M1_MemHalf),
        .M1_MemByte        (M1_MemByte),
        .M1_Left           (M1_Left),
        .M1_Right          (M1_Right),
        .M1_MemSignExtend  (M1_MemSignExtend),
        .M1_BigEndian      (M1_BigEndian),
        .M1_Div            (M1_Div),
        .M1_RegWrite       (M1_RegWrite),
        .M1_HiWrite        (M1_HiWrite),
        .M1_LoWrite        (M1_LoWrite),
        .M1_MemToReg       (M1_MemToReg),
        .M1_ALUResult      (M1_ALUResult),
        .M1_UnalignedReg   (M1_WriteData_End),
        .M1_Mtc0           (M1_Mtc0),
        .M1_TLBp           (M1_TLBp),
        .M1_TLBr           (M1_TLBr),
        .M1_TLBwi          (M1_TLBwi),
        .M1_TLBwr          (M1_TLBwr),
        .M1_ICacheOp       (M1_ICacheOp),
        .M1_Eret           (M1_Eret),
        .M1_XOP            (M1_XOP),
        .M1_BadVAddr       (M1_BadVAddr),
        .M2_M1Issued       (M2_M1Issued),
        .M2_M1Exception    (M2_M1Exception),
        .M2_M1ExcCode      (M2_M1ExcCode),
        .M2_RestartPC      (M2_RestartPC),
        .M2_IsBDS          (M2_IsBDS),
        .M2_RtRd           (M2_RtRd),
        .M2_CP0Sel         (M2_CP0Sel),
        .M2_LLSC           (M2_LLSC),
        .M2_MemRead        (M2_MemRead),
        .M2_MemReadIssued  (M2_MemReadIssued),
        .M2_MemWrite       (M2_MemWrite),
        .M2_MemWriteIssued (M2_MemWriteIssued),
        .M2_MemHalf        (M2_MemHalf),
        .M2_MemByte        (M2_MemByte),
        .M2_Left           (M2_Left),
        .M2_Right          (M2_Right),
        .M2_MemSignExtend  (M2_MemSignExtend),
        .M2_BigEndian      (M2_BigEndian),
        .M2_Div            (M2_Div),
        .M2_RegWrite       (M2_RegWrite),
        .M2_HiWrite        (M2_HiWrite),
        .M2_LoWrite        (M2_LoWrite),
        .M2_MemToReg       (M2_MemToReg),
        .M2_ALUResult      (M2_ALUResult),
        .M2_UnalignedReg   (M2_UnalignedReg),
        .M2_Mtc0           (M2_Mtc0),
        .M2_TLBp           (M2_TLBp),
        .M2_TLBr           (M2_TLBr),
        .M2_TLBwi          (M2_TLBwi),
        .M2_TLBwr          (M2_TLBwr),
        .M2_ICacheOp       (M2_ICacheOp),
        .M2_Eret           (M2_Eret),
        .M2_XOP            (M2_XOP),
        .M2_BadVAddr       (M2_M1BadVAddr)
    );

    //*** M2 Read Data Control ***//
    ReadDataControl ReadControl (
        .Address     (M2_ALUResult[1:0]),
        .Byte        (M2_MemByte),
        .Half        (M2_MemHalf),
        .SignExtend  (M2_MemSignExtend),
        .Left        (M2_Left),
        .Right       (M2_Right),
        .BigEndian   (M2_BigEndian),
        .SC          (M2_SC),
        .Atomic      (M2_Atomic),
        .RegData     (M2_UnalignedReg),
        .ReadData    (DataMem_In),
        .DataOut     (M2_ReadData)
    );

    //*** Writeback Stage Register ***//
    W1_Stage #(.PABITS(PABITS)) W1 (
        .clock                (clock),
        .reset                (reset),
        .M2_Issued            (M2_Issued),
        .M2_Exception         (M2_Exception),
        .M2_ExcCode           (M2_ExcCode),
        .W1_Stall             (W1_Stall),
        .W1_Flush             (W1_Flush),
        .W1_Issued            (W1_Issued),
        .M2_RestartPC         (M2_RestartPC),
        .M2_IsBDS             (M2_IsBDS),
        .M2_MemRWIssued       (M2_MemWriteIssued | M2_MemReadIssued),
        .M2_RtRd              (M2_RtRd),
        .M2_CP0Sel            (M2_CP0Sel),
        .M2_Div               (M2_Div),
        .M2_RegWrite          (M2_RegWrite),
        .M2_HiWrite           (M2_HiWrite),
        .M2_LoWrite           (M2_LoWrite),
        .M2_MemToReg          (M2_MemToReg),
        .M2_ALUResult         (M2_ALUResult),
        .M2_ReadData          (M2_ReadData),
        .M2_Mtc0              (M2_Mtc0),
        .M2_TLBp              (M2_TLBp),
        .M2_TLBr              (M2_TLBr),
        .M2_TLBwi             (M2_TLBwi),
        .M2_TLBwr             (M2_TLBwr),
        .M2_TLBIndex          (M2_TLBIndex),
        .M2_ICacheOp          (M2_ICacheOp),
        .M2_Eret              (M2_Eret),
        .M2_XOP               (M2_XOP),
        .M2_Tlbp_Hit          (M2_Tlbp_Hit),
        .M2_Tlbp_Index        (M2_Tlbp_Index),
        .M2_Tlbr_result       (M2_Tlbr_result),
        .M2_BadVAddr          (M2_BadVAddr),
        .W1_M2Issued          (W1_M2Issued),
        .W1_M2Exception       (W1_M2Exception),
        .W1_M2ExcCode         (W1_M2ExcCode),
        .W1_RestartPC         (W1_RestartPC),
        .W1_IsBDS             (W1_IsBDS),
        .W1_M2MemRWIssued     (W1_M2MemRWIssued),
        .W1_RtRd              (W1_RtRd),
        .W1_CP0Sel            (W1_CP0Sel),
        .W1_Div               (W1_Div),
        .W1_RegWrite          (W1_RegWrite),
        .W1_HiWrite           (W1_HiWrite),
        .W1_LoWrite           (W1_LoWrite),
        .W1_MemToReg          (W1_MemToReg),
        .W1_ALUResult         (W1_ALUResult),
        .W1_ReadData          (W1_ReadData),
        .W1_Mtc0              (W1_Mtc0),
        .W1_TLBp              (W1_TLBp),
        .W1_TLBr              (W1_TLBr),
        .W1_TLBwi             (W1_TLBwi),
        .W1_TLBwr             (W1_TLBwr),
        .W1_TLBIndex          (W1_TLBIndex),
        .W1_ICacheOp          (W1_ICacheOp),
        .W1_Eret              (W1_Eret),
        .W1_XOP               (W1_XOP),
        .W1_Tlbp_Hit          (W1_Tlbp_Hit),
        .W1_Tlbp_Index        (W1_Tlbp_Index),
        .W1_Tlbr_result       (W1_Tlbr_result),
        .W1_BadVAddr          (W1_BadVAddr)
    );

    //*** W1 Write Data Mux ***//
    Mux4 #(.WIDTH(32)) W1WriteData_Mux (
        .sel (W1_WriteDataSel),
        .in0 (W1_ALUResult),
        .in1 (W1_ReadData),
        .in2 (ALU_Mult_Out[31:0]),
        .in3 ({32{1'bx}}),
        .out (W1_WriteData)
    );

endmodule

