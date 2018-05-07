`timescale 1ns / 1ps
/*
 * File         : CPZero.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The MIPS-32 Coprocessor 0 (CP0). This is the processor management unit that allows
 *   interrupts, traps, system calls, and other exceptions. It distinguishes
 *   user and kernel modes, provides status information, and can override program flow.
 */
module CPZero #(parameter PABITS=36) (
    input         clock,
    input         reset,
    input         reset_r,            // Clock-registered reset
    input         W1_Issued,          // Condition for CP0 writes
    input  [31:0] W1_Reg_In,          // Data from GP register to write to CP0 register in W1
    input         F2_Stall,           // Hold TLB data
    input         M2_Stall,           // Hold TLB data
    //-- GPR access signals --//
    input  [4:0]  D1_Rd,              // Specifies Cp0 read register from D1 (TODO: Could do this in D2 as well)
    input  [2:0]  D1_Sel,             // Specifies Cp0 read 'select' (subregister) from D1
    output [31:0] D1_Reg_Out,         // Data from a CP0 register for a GP register
    input  [4:0]  W1_Rd,              // Specifies Cp0 write register from W1 instruction Rd field
    input  [2:0]  W1_Sel,             // Specifies Cp0 write 'select' (subregister) from W1
    input         W1_Mtc0,            // Cp0 write instruction in W1
    //-- TLB access signals --//
    input  [19:0] F1_VPN,             // Instruction memory virtual address (virtual page number)
    input  [19:0] M1_VPN,             // Data memory address (virtual page number)
    input         F2_TLB_L,           // The TLB was accessed in F1 for a load operation
    input         M2_TLB_L,           // The TLB was accessed in M1 for a load operation
    input         M2_TLB_S,           // The TLB was accessed in M1 for a store operation
    output [(PABITS-13):0] F2_PFN,    // Instruction memory physical address translation
    output [(PABITS-13):0] M2_PFN,    // Data memory physical address translation
    output [2:0]  F2_Cache,           // Instruction memory physical address cache attributes
    output [2:0]  M2_Cache,           // Data memory physical address cache attributes
    output        F2_PFN_Valid,       // Instruction memory hit/miss
    output        M2_PFN_Valid,       // Data memory hit/miss
    //-- TLB command signals --//
    input         M1_Tlbp,            // TLB begin probe
    input         M1_Tlbr,            // TLB begin read
    input         W1_Tlbp,            // TLB probe instruction in W1 (indicates match, index bits from prior TLB probe)
    input         W1_Tlbr,            // TLB read instruction in W1 (indicates page mask, entry hi/lo bits from prior TLB read)
    input         W1_Tlbwi,           // TLB write indexed instruction in W1 (indicates page mask, entry hi/lo bits for TLB write)
    input         W1_Tlbwr,           // TLB write random instruction in W1 (indicates page mask, entry hi/lo bits for TLB write)
    output        M2_Tlbp_Hit,        // TLB probe hit result in M2
    output [3:0]  M2_Tlbp_Index,      // TLB probe index result in M2
    input         W1_Tlbp_Hit,        // TLB probe hit result in W1
    input  [3:0]  W1_Tlbp_Index,      // TLB probe index in W1
    output [(29+(2*PABITS)):0] M2_Tlbr_result, // TLB read result in M2. Below is result in W1 ready to commit (same data arrangement)
    input  [(29+(2*PABITS)):0] W1_Tlbr_result, // {PFN0, PFN1, VPN2[53:35], Mask[34:19], ASID[18:11], C0[10:8], C1[7:5], D0[4], D1[3], V0[2], V1[1], G[0]}
    input  [3:0]  W1_TLBIndex,        // Fixed/Random index for tlbwi/tlbr
    //-- Exception detection --//
    input  [4:0]  Int,                // Five hardware interrupts external to the processor
    input         NMI,                // Non-maskable interrupt exception external to the processor
    input         D2_COP0,            // Cp0 access instruction in D2 (cache, eret, mfc0, mtc0, tlb{p,r,wi,wr})
    input         D2_COP1,            // Cp1 access instruction in D2
    input         D2_COP2,            // Cp2 access instruction in D2
    input         D2_COP3,            // Cp3 access instruction in D2
    output        F2_EXC_TlbRi,       // TLB refill exception (instruction memory)
    output        F2_EXC_TlbIi,       // TLB invalid exception (instruction memory)
    output        D2_EXC_CpU0,        // Cp0 unusable exception
    output        D2_EXC_CpU1,        // Cp1 unusable exception
    output        D2_EXC_CpU2,        // Cp2 unusable exception
    output        D2_EXC_CpU3,        // Cp3 unusable exception
    output        M2_EXC_TlbRLd,      // TLB refill exception (data memory, load)
    output        M2_EXC_TlbRSd,      // TLB refill exception (data memory, store)
    output        M2_EXC_TlbILd,      // TLB invalid exception (data memory, load)
    output        M2_EXC_TlbISd,      // TLB invalid exception (data memory, store)
    output        M2_EXC_TlbMd,       // TLB modified exception (data memory, store)
    output        Enabled_Int,        // A non-masked interrupt is available (not necessarily active)
    //-- Exception handling --//
    input         W1_ExcActive,       // Indicates an active exception, interrupt, or NMI
    input  [4:0]  W1_ExcCode,         // Exception code (non-NMI) in W1
    input  [31:0] W1_ExcVAddr,        // Exception virtual address in W1
    input  [31:0] W1_ExcRestartPC,    // Restart PC for W1
    input         W1_ExcIsBDS,        // W1 is a branch delay slot
    input         W1_Eret,            // Eret instruction in W1
    output        D2_Exc_PC_Sel,      // Mux selector for exception PC override
    output [31:0] D2_Exc_PC_Out,      // Address for PC at the beginning of / return from an exception
    //-- Misc --//
    output [(PABITS-8):0] Cache_Out,  // Currently used for 'Store Tag' cache subinstruction (TagLo/Hi)
    output [3:0]  Index_Out,          // Index register (TLB)
    output [3:0]  Random_Out,         // Random register (TLB)
    output        M1_ReverseEndian,   // Reverse-endian user mode memory accesses (masked in kernel mode)
    output        M1_KernelMode       // Kernel mode (used by M1 but valid for all stages)
    );

    // XXX What happens if exception PC from W1 but F stages are stalled? Or j/branch in D2 but F is stalled?

    /* CP0 Writes:
     *  - GPR writes (mtc0) depend on W1_Issued, where 'W1_Issued' includes W1 masking (incl. exceptions).
     *  - TLB operations (tlb{p,r,wi,wr}) depend on W1_Issued as above.
     *  - Cache instructions (cache) depend on W1_Issued as above.
     *  - Exceptions/interrupts (*) depend on W1_ExcActive.
     *  - Eret depends on W1_Issued as above.
     */

    /* Exception Handling:
     *  - Exceptions, interrupts, and Eret modify the program counter. There is no delay slot.
     *  - Procedure:
     *      1. An exception/interrupt/eret is detected in W1.
     *      2. W1 stalls while the I/D caches are busy waiting for main memory.
     *      3. Every pipeline stage is flushed (except relevant CP0 writes) while the new PC is sent to F1.
     */

    `include "MIPS_Defines.v"

    // Register module signals
    wire                      Reg_W1_Issued;
    wire [31:0]               Reg_DataIn;
    wire                      Reg_Mtc0;
    wire [4:0]                Reg_Rd;
    wire [2:0]                Reg_Sel;
    wire [31:0]               Reg_DataOut;
    wire                      Reg_TLBp_Write;
    wire                      Reg_TLBr_Write;
    wire                      Reg_TLBp_NoMatch;
    wire [3:0]                Reg_TLBp_Index;
    wire [18:0]               Reg_TLBr_VPN2;
    wire [15:0]               Reg_TLBr_Mask;
    wire [7:0]                Reg_TLBr_ASID;
    wire [(23-(36-PABITS)):0] Reg_TLBr_PFN0;
    wire [2:0]                Reg_TLBr_C0;
    wire                      Reg_TLBr_D0;
    wire                      Reg_TLBr_V0;
    wire [(23-(36-PABITS)):0] Reg_TLBr_PFN1;
    wire [2:0]                Reg_TLBr_C1;
    wire                      Reg_TLBr_D1;
    wire                      Reg_TLBr_V1;
    wire                      Reg_TLBr_G;
    wire [4:0]                Reg_Int;
    wire                      Reg_ExcActive;
    wire                      Reg_NMI;
    wire [4:0]                Reg_ExcCode;
    wire [31:0]               Reg_ExcVAddr;
    wire [31:0]               Reg_RestartPC;
    wire                      Reg_IsBDS;
    wire                      Reg_Eret;
    wire [(PABITS-8):0]       Reg_CacheTag_Out;
    wire                      Reg_ReverseEndian;
    wire [3:0]                Reg_Index_Out;
    wire [3:0]                Reg_Random_Out;
    wire [15:0]               Reg_PageMask_Out;
    wire [26:0]               Reg_EntryHi_Out;
    wire [(PABITS-7):0]       Reg_EntryLo0_Out;
    wire [(PABITS-7):0]       Reg_EntryLo1_Out;
    wire                      Reg_Status_BEV_Out;
    wire                      Reg_Status_ERL_Out;
    wire                      Reg_Status_EXL_Out;
    wire                      Reg_Cause_IV_Out;
    wire [31:0]               Reg_EPC_Out;
    wire [31:0]               Reg_ErrorEPC_Out;
    wire [2:0]                Reg_K0;
    wire                      Reg_Enabled_Int;
    wire                      Reg_KernelMode;
    wire                      Reg_CP0_User;

    // TLB signals
    wire [19:0]          TLB_VPN_I;
    wire [7:0]           TLB_ASID_I;
    wire                 TLB_Hit_I;
    wire [(PABITS-13):0] TLB_PFN_I;
    wire [2:0]           TLB_Cache_I;
    wire                 TLB_Valid_I;
    wire                 TLB_Stall_I;
    wire [19:0]          TLB_VPN_D;
    wire [7:0]           TLB_ASID_D;
    wire                 TLB_Hit_D;
    wire [(PABITS-13):0] TLB_PFN_D;
    wire [2:0]           TLB_Cache_D;
    wire                 TLB_Dirty_D;
    wire                 TLB_Valid_D;
    wire                 TLB_Stall_D;
    wire [3:0]           TLB_Index_In;
    wire [18:0]          TLB_VPN2_In;
    wire [15:0]          TLB_Mask_In;
    wire [7:0]           TLB_ASID_In;
    wire                 TLB_G_In;
    wire [(PABITS-13):0] TLB_PFN0_In, TLB_PFN1_In;
    wire [2:0]           TLB_C0_In, TLB_C1_In;
    wire                 TLB_D0_In, TLB_D1_In;
    wire                 TLB_V0_In, TLB_V1_In;
    wire [3:0]           TLB_Index_Out;
    wire [18:0]          TLB_VPN2_Out;
    wire [15:0]          TLB_Mask_Out;
    wire [7:0]           TLB_ASID_Out;
    wire                 TLB_G_Out;
    wire [(PABITS-13):0] TLB_PFN0_Out, TLB_PFN1_Out;
    wire [2:0]           TLB_C0_Out, TLB_C1_Out;
    wire                 TLB_D0_Out, TLB_D1_Out;
    wire                 TLB_V0_Out, TLB_V1_Out;
    wire                 TLB_Read;
    wire                 TLB_Write;
    wire                 TLB_Useg_MC;
    wire [2:0]           TLB_Kseg0_C;

    // Local signals
    wire  [18:0]               W1_Tlbr_VPN2;
    wire  [15:0]               W1_Tlbr_Mask;
    wire  [7:0]                W1_Tlbr_ASID;
    wire  [(23-(36-PABITS)):0] W1_Tlbr_PFN0;
    wire  [2:0]                W1_Tlbr_C0;
    wire                       W1_Tlbr_D0;
    wire                       W1_Tlbr_V0;
    wire  [(23-(36-PABITS)):0] W1_Tlbr_PFN1;
    wire  [2:0]                W1_Tlbr_C1;
    wire                       W1_Tlbr_D1;
    wire                       W1_Tlbr_V1;
    wire                       W1_Tlbr_G;
    wire                       exc_refill;
    reg  [31:0]                exc_pc;
    wire [31:0]                EPC;
    wire [31:0]                ErrorEPC;
    wire                       Status_ERL;
    wire                       Status_EXL;
    wire                       Status_BEV;
    wire                       Cause_IV;

    // Top-level assignments
    assign D1_Reg_Out       = Reg_DataOut;
    assign F2_PFN           = TLB_PFN_I;
    assign M2_PFN           = TLB_PFN_D;
    assign F2_Cache         = TLB_Cache_I;
    assign M2_Cache         = TLB_Cache_D;
    assign F2_PFN_Valid     = &{TLB_Hit_I, TLB_Valid_I, F2_TLB_L};
    assign M2_PFN_Valid     = &{TLB_Hit_D, TLB_Valid_D, (M2_TLB_L | (M2_TLB_S & TLB_Dirty_D))};
    assign M2_Tlbp_Hit      = TLB_Hit_D;
    assign M2_Tlbp_Index    = TLB_Index_Out;
    assign M2_Tlbr_result   = {TLB_PFN0_Out, TLB_PFN1_Out, TLB_VPN2_Out, TLB_Mask_Out, TLB_ASID_Out,
                               TLB_C0_Out, TLB_C1_Out, TLB_D0_Out, TLB_D1_Out, TLB_V0_Out, TLB_V1_Out, TLB_G_Out};
    assign F2_EXC_TlbRi     = &{F2_TLB_L, ~TLB_Hit_I};
    assign F2_EXC_TlbIi     = &{F2_TLB_L,  TLB_Hit_I, ~TLB_Valid_I};
    assign D2_EXC_CpU0      = &{D2_COP0, ~Reg_CP0_User, ~Reg_KernelMode};
    assign D2_EXC_CpU1      = D2_COP1;
    assign D2_EXC_CpU2      = D2_COP2;
    assign D2_EXC_CpU3      = D2_COP3;
    assign M2_EXC_TlbRLd    = &{M2_TLB_L, ~TLB_Hit_D};
    assign M2_EXC_TlbRSd    = &{M2_TLB_S, ~TLB_Hit_D};
    assign M2_EXC_TlbILd    = &{M2_TLB_L,  TLB_Hit_D, ~TLB_Valid_D};
    assign M2_EXC_TlbISd    = &{M2_TLB_S,  TLB_Hit_D, ~TLB_Valid_D};
    assign M2_EXC_TlbMd     = &{M2_TLB_S,  TLB_Hit_D,  TLB_Valid_D, ~TLB_Dirty_D};
    assign Enabled_Int      = Reg_Enabled_Int;
    assign D2_Exc_PC_Sel    = reset_r | W1_ExcActive | (W1_Issued & W1_Eret);
    assign D2_Exc_PC_Out    = exc_pc;
    assign Cache_Out        = Reg_CacheTag_Out;
    assign Index_Out        = Reg_Index_Out;
    assign Random_Out       = Reg_Random_Out;
    assign M1_ReverseEndian = &{Reg_ReverseEndian, ~Reg_KernelMode};
    assign M1_KernelMode    = Reg_KernelMode;

    // Local assignments
    assign W1_Tlbr_VPN2 = W1_Tlbr_result[53:35];
    assign W1_Tlbr_Mask = W1_Tlbr_result[34:19];
    assign W1_Tlbr_ASID = W1_Tlbr_result[18:11];
    assign W1_Tlbr_PFN0 = W1_Tlbr_result[(29+(2*PABITS)):(55+(PABITS-13))];
    assign W1_Tlbr_C0   = W1_Tlbr_result[10:8];
    assign W1_Tlbr_D0   = W1_Tlbr_result[4];
    assign W1_Tlbr_V0   = W1_Tlbr_result[2];
    assign W1_Tlbr_PFN1 = W1_Tlbr_result[(54+(PABITS-13)):54];
    assign W1_Tlbr_C1   = W1_Tlbr_result[7:5];
    assign W1_Tlbr_D1   = W1_Tlbr_result[3];
    assign W1_Tlbr_V1   = W1_Tlbr_result[1];
    assign W1_Tlbr_G    = W1_Tlbr_result[0];
    assign exc_refill   = |{(W1_ExcCode == `Exc_TlbRi), (W1_ExcCode == `Exc_TlbRLd), (W1_ExcCode == `Exc_TlbRSd)};
    assign EPC          = Reg_EPC_Out;
    assign ErrorEPC     = Reg_ErrorEPC_Out;
    assign Status_ERL   = Reg_Status_ERL_Out;
    assign Status_EXL   = Reg_Status_EXL_Out;
    assign Status_BEV   = Reg_Status_BEV_Out;
    assign Cause_IV     = Reg_Cause_IV_Out;

    always @(*) begin
        if (reset_r | (W1_ExcActive & NMI)) begin
            exc_pc <= `EXC_Vector_Reset;
        end
        else if (W1_Eret) begin
            exc_pc <= (Status_ERL) ? ErrorEPC : EPC;
        end
        else if (&{exc_refill, ~Status_EXL}) begin
            exc_pc <= (Status_BEV) ? (`EXC_Vector_Base_General_Boot   + `EXC_Vector_Offset_None) :          // 0xBFC0_0200
                                     (`EXC_Vector_Base_General_NoBoot + `EXC_Vector_Offset_None);           // 0x8000_0000
        end
        else if ((W1_ExcCode == `Exc_Int) & Cause_IV) begin
            exc_pc <= (Status_BEV) ? (`EXC_Vector_Base_General_Boot   + `EXC_Vector_Offset_Interrupt) :     // 0xBFC0_0400
                                     (`EXC_Vector_Base_General_NoBoot + `EXC_Vector_Offset_Interrupt);      // 0x8000_0200
        end
        else begin
            exc_pc <= (Status_BEV) ? (`EXC_Vector_Base_General_Boot   + `EXC_Vector_Offset_General) :       // 0xBFC0_0380
                                     (`EXC_Vector_Base_General_NoBoot + `EXC_Vector_Offset_General);        // 0x8000_0180
        end
    end

    // Register module assignments
    assign Reg_W1_Issued    = W1_Issued;
    assign Reg_DataIn       = W1_Reg_In;
    assign Reg_Mtc0         = W1_Mtc0;
    assign Reg_Rd           = (W1_Mtc0) ? W1_Rd : D1_Rd;   // Mtc0 and Mfc0 must be mutually-exclusive in the pipeline
    assign Reg_Sel          = (W1_Mtc0) ? W1_Sel : D1_Sel; // For XOP restarts, W1_Mtc0 is masked earlier to avoid timing delays with W1_Issued
    assign Reg_TLBp_Write   = W1_Tlbp;
    assign Reg_TLBr_Write   = W1_Tlbr;
    assign Reg_TLBp_NoMatch = ~W1_Tlbp_Hit;
    assign Reg_TLBp_Index   = W1_Tlbp_Index;
    assign Reg_TLBr_VPN2    = W1_Tlbr_VPN2;
    assign Reg_TLBr_Mask    = W1_Tlbr_Mask;
    assign Reg_TLBr_ASID    = W1_Tlbr_ASID;
    assign Reg_TLBr_PFN0    = W1_Tlbr_PFN0;
    assign Reg_TLBr_C0      = W1_Tlbr_C0;
    assign Reg_TLBr_D0      = W1_Tlbr_D0;
    assign Reg_TLBr_V0      = W1_Tlbr_V0;
    assign Reg_TLBr_PFN1    = W1_Tlbr_PFN1;
    assign Reg_TLBr_C1      = W1_Tlbr_C1;
    assign Reg_TLBr_D1      = W1_Tlbr_D1;
    assign Reg_TLBr_V1      = W1_Tlbr_V1;
    assign Reg_TLBr_G       = W1_Tlbr_G;
    assign Reg_Int          = Int;
    assign Reg_ExcActive    = W1_ExcActive;
    assign Reg_NMI          = NMI;
    assign Reg_ExcCode      = W1_ExcCode;
    assign Reg_ExcVAddr     = W1_ExcVAddr;
    assign Reg_RestartPC    = W1_ExcRestartPC;
    assign Reg_IsBDS        = W1_ExcIsBDS;
    assign Reg_Eret         = W1_Eret;

    // TLB assignments
    assign TLB_VPN_I    = F1_VPN;
    assign TLB_ASID_I   = Reg_EntryHi_Out[7:0];
    assign TLB_Stall_I  = F2_Stall;
    assign TLB_VPN_D    = (M1_Tlbp) ? {Reg_EntryHi_Out[26:8], 1'b0} : M1_VPN;
    assign TLB_ASID_D   = Reg_EntryHi_Out[7:0];
    assign TLB_Stall_D  = M2_Stall;
    assign TLB_Index_In = W1_TLBIndex;
    assign TLB_VPN2_In  = Reg_EntryHi_Out[26:8];
    assign TLB_Mask_In  = Reg_PageMask_Out;
    assign TLB_ASID_In  = Reg_EntryHi_Out[7:0];
    assign TLB_G_In     = Reg_EntryLo0_Out[0] & Reg_EntryLo1_Out[0];
    assign TLB_PFN0_In  = Reg_EntryLo0_Out[(PABITS-7):6];
    assign TLB_C0_In    = Reg_EntryLo0_Out[5:3];
    assign TLB_D0_In    = Reg_EntryLo0_Out[2];
    assign TLB_V0_In    = Reg_EntryLo0_Out[1];
    assign TLB_PFN1_In  = Reg_EntryLo1_Out[(PABITS-7):6];
    assign TLB_C1_In    = Reg_EntryLo1_Out[5:3];
    assign TLB_D1_In    = Reg_EntryLo1_Out[2];
    assign TLB_V1_In    = Reg_EntryLo1_Out[1];
    assign TLB_Read     = M1_Tlbr;
    assign TLB_Write    = (W1_Tlbwi | W1_Tlbwr) & W1_Issued;
    assign TLB_Useg_MC  = ~Reg_Status_ERL_Out;
    assign TLB_Kseg0_C  = Reg_K0;

    // CP0 Registers
    CP0_Registers #(.PABITS(PABITS)) Registers (
        .clock           (clock),               // input clock
        .reset           (reset),               // input reset
        .W1_Issued       (Reg_W1_Issued),       // input W1_Issued
        .DataIn          (Reg_DataIn),          // input [31 : 0] DataIn
        .Mtc0            (Reg_Mtc0),            // input Mtc0
        .Rd              (Reg_Rd),              // input [4:0] Rd
        .Sel             (Reg_Sel),             // input [2:0] Sel
        .DataOut         (Reg_DataOut),         // output [31:0] DataOut
        .TLBp_Write      (Reg_TLBp_Write),      // input TLBp_Write
        .TLBr_Write      (Reg_TLBr_Write),      // input TLBr_Write
        .TLBp_NoMatch    (Reg_TLBp_NoMatch),    // input TLBp_NoMatch
        .TLBp_Index      (Reg_TLBp_Index),      // input [3 : 0] TLBp_Index
        .TLBr_VPN2       (Reg_TLBr_VPN2),       // input [18 : 0] TLBr_VPN2
        .TLBr_Mask       (Reg_TLBr_Mask),       // input [15 : 0] TLBr_Mask
        .TLBr_ASID       (Reg_TLBr_ASID),       // input [7 : 0] TLBr_ASID
        .TLBr_PFN0       (Reg_TLBr_PFN0),       // input [ : ] TLBr_PFN0
        .TLBr_C0         (Reg_TLBr_C0),         // input [2 : 0] TLBr_C0
        .TLBr_D0         (Reg_TLBr_D0),         // input TLBr_D0
        .TLBr_V0         (Reg_TLBr_V0),         // input TLBr_V0
        .TLBr_PFN1       (Reg_TLBr_PFN1),       // input [ : ] TLBr_PFN1
        .TLBr_C1         (Reg_TLBr_C1),         // input [2 : 0] TLBr_C1
        .TLBr_D1         (Reg_TLBr_D1),         // input TLBr_D1
        .TLBr_V1         (Reg_TLBr_V1),         // input TLBr_V1
        .TLBr_G          (Reg_TLBr_G),          // input TLBr_G
        .Int             (Reg_Int),             // input [4 : 0] Int
        .ExcActive       (Reg_ExcActive),       // input ExcActive
        .NMI             (Reg_NMI),             // input NMI
        .ExcCode         (Reg_ExcCode),         // input [4 : 0] ExcCode
        .ExcVAddr        (Reg_ExcVAddr),        // input [31 : 0] ExcVAddr
        .RestartPC       (Reg_RestartPC),       // input [31 : 0] RestartPC
        .IsBDS           (Reg_IsBDS),           // input IsBDS
        .Eret            (Reg_Eret),            // input Eret
        .CacheTag_Out    (Reg_CacheTag_Out),    // output [ : ] CacheTag_Out
        .ReverseEndian   (Reg_ReverseEndian),   // output ReverseEndian
        .Index_Out       (Reg_Index_Out),       // output [3 : 0] Index_Out
        .Random_Out      (Reg_Random_Out),      // output [3 : 0] Random_Out
        .PageMask_Out    (Reg_PageMask_Out),    // output [15 : 0] PageMask_Out
        .EntryHi_Out     (Reg_EntryHi_Out),     // output [26 : 0] EntryHi_Out
        .EntryLo0_Out    (Reg_EntryLo0_Out),    // output [ : ] EntryLo0_Out
        .EntryLo1_Out    (Reg_EntryLo1_Out),    // output [ : ] EntryLo1_Out
        .Status_BEV_Out  (Reg_Status_BEV_Out),  // output Status_BEV_Out
        .Status_ERL_Out  (Reg_Status_ERL_Out),  // output Status_ERL_Out
        .Status_EXL_Out  (Reg_Status_EXL_Out),  // output Status_EXL_Out
        .Cause_IV_Out    (Reg_Cause_IV_Out),    // output Cause_IV_Out
        .EPC_Out         (Reg_EPC_Out),         // output [31 : 0] EPC_Out
        .ErrorEPC_Out    (Reg_ErrorEPC_Out),    // output [31 : 0] ErrorEPC_Out
        .K0              (Reg_K0),              // output [2 : 0] K0
        .Enabled_Int     (Reg_Enabled_Int),     // output EnabledInt
        .KernelMode      (Reg_KernelMode),      // output KernelMode
        .CP0_User        (Reg_CP0_User)         // output CP0_User
    );

    // Translation Lookaside Buffer (TLB)
    TLB_16 #(.PABITS(PABITS)) TLB (
        .clock      (clock),            // input clock
        .reset      (reset),            // input reset
        .VPN_I      (TLB_VPN_I),        // input [19 : 0] VPN_I
        .ASID_I     (TLB_ASID_I),       // input [7 : 0] ASID_I
        .Hit_I      (TLB_Hit_I),        // output Hit_I
        .PFN_I      (TLB_PFN_I),        // output [23 : 0] PFN_I
        .Cache_I    (TLB_Cache_I),      // output [2 : 0] Cache_I
        .Dirty_I    (),                 // output Dirty_I
        .Valid_I    (TLB_Valid_I),      // output Valid_I
        .Stall_I    (TLB_Stall_I),      // input Stall_I
        .VPN_D      (TLB_VPN_D),        // input [19 : 0] VPN_D
        .ASID_D     (TLB_ASID_D),       // input [7 : 0] ASID_D
        .Hit_D      (TLB_Hit_D),        // output Hit_D
        .PFN_D      (TLB_PFN_D),        // output [23 : 0] PFN_D
        .Cache_D    (TLB_Cache_D),      // output [2 : 0] Cache_D
        .Dirty_D    (TLB_Dirty_D),      // output Dirty_D
        .Valid_D    (TLB_Valid_D),      // output Valid_D
        .Stall_D    (TLB_Stall_D),      // input Stall_D
        .Index_In   (TLB_Index_In),     // input [3 : 0] Index_In
        .VPN2_In    (TLB_VPN2_In),      // input [18 : 0] VPN2_In
        .Mask_In    (TLB_Mask_In),      // input [15 : 0] Mask_In
        .ASID_In    (TLB_ASID_In),      // input [7 : 0] ASID_In
        .G_In       (TLB_G_In),         // input G_In
        .PFN0_In    (TLB_PFN0_In),      // input [23 : 0] PFN0_In
        .C0_In      (TLB_C0_In),        // input [2 : 0] C0_In
        .D0_In      (TLB_D0_In),        // input D0_In
        .V0_In      (TLB_V0_In),        // input V0_In
        .PFN1_In    (TLB_PFN1_In),      // input [23 : 0] PFN1_In
        .C1_In      (TLB_C1_In),        // input [2 : 0] C1_In
        .D1_In      (TLB_D1_In),        // input D1_In
        .V1_In      (TLB_V1_In),        // input V1_In
        .Index_Out  (TLB_Index_Out),    // output [3 : 0] Index_Out
        .VPN2_Out   (TLB_VPN2_Out),     // output [18 : 0] VPN2_Out
        .Mask_Out   (TLB_Mask_Out),     // output [15 : 0] Mask_Out
        .ASID_Out   (TLB_ASID_Out),     // output [7 : 0] ASID_Out
        .G_Out      (TLB_G_Out),        // output G_Out
        .PFN0_Out   (TLB_PFN0_Out),     // output [23 : 0] PFN0_Out
        .C0_Out     (TLB_C0_Out),       // output [2 : 0] C0_Out
        .D0_Out     (TLB_D0_Out),       // output D0_Out
        .V0_Out     (TLB_V0_Out),       // output V0_Out
        .PFN1_Out   (TLB_PFN1_Out),     // output [23 : 0] PFN1_Out
        .C1_Out     (TLB_C1_Out),       // output [2 : 0] C1_Out
        .D1_Out     (TLB_D1_Out),       // output D1_Out
        .V1_Out     (TLB_V1_Out),       // output V1_Out
        .Read       (TLB_Read),         // input Read
        .Write      (TLB_Write),        // input Write
        .Useg_MC    (TLB_Useg_MC),      // input Useg_MC
        .Kseg0_C    (TLB_Kseg0_C)       // input [2 : 0] Kseg0_C
    );

endmodule

