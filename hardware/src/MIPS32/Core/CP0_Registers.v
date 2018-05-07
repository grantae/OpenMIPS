`timescale 1ns / 1ps
/*
 * File         : CP0_Registers.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   20-Nov-2014  GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   MIPS32r1 Coprocessor 0 Registers
 */
module CP0_Registers #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    input                  W1_Issued,      // W1 was not previously stalled/flushed (it's active)
    //-- GPR Accesses --//
    input  [31:0]          DataIn,         // CP0 write data (mtc0)
    input                  Mtc0,           // CP0 write instruction in W1
    input  [4:0]           Rd,             // CP0 register select from instruction bits
    input  [2:0]           Sel,            // CP0 subregister select from instruction bits
    output [31:0]          DataOut,        // Data for 'mfc0': CP0 register to GP register
    //-- TLB input data  --//
    input                  TLBp_Write,     // Write the values associated with Tlbp (Index) (signal in W1)
    input                  TLBr_Write,     // Write the values associated with Tlbr (Entry{Lo,Hi}, PageMask) (signal in W1)
    input                  TLBp_NoMatch,   // TLB read probe miss (Tlbp) (writes to Index) (signal in W1)
    input  [3:0]           TLBp_Index,     // TLB read probe index (Tlbp) (writes to Index) (signal in W1)
    input  [18:0]          TLBr_VPN2,      // TLB read VPN2 (Tlbr) (writes to EntryHi) (signal in W1)
    input  [15:0]          TLBr_Mask,      // TLB read mask (Tlbr) (writes to PageMask) (signal in W1)
    input  [7:0]           TLBr_ASID,      // TLB read ASID (Tlbr) (writes to EntryHi) (signal in W1)
    input  [(23-(36-PABITS)):0] TLBr_PFN0, // TLB read PFN0 (Tlbr) (writes to EntryLo) (signal in W1)
    input  [2:0]           TLBr_C0,        // TLB read C0 (Tlbr) (writes to EntryLo) (signal in W1)
    input                  TLBr_D0,        // TLB read D0 (Tlbr) (writes to EntryLo) (signal in W1)
    input                  TLBr_V0,        // TLB read V0 (Tlbr) (writes to EntryLo) (signal in W1)
    input  [(23-(36-PABITS)):0] TLBr_PFN1, // TLB read PFN1 (Tlbr) (writes to EntryLo) (signal in W1)
    input  [2:0]           TLBr_C1,        // TLB read C1 (Tlbr) (writes to EntryLo) (signal in W1)
    input                  TLBr_D1,        // TLB read D1 (Tlbr) (writes to EntryLo) (signal in W1)
    input                  TLBr_V1,        // TLB read V1 (Tlbr) (writes to EntryLo) (signal in W1)
    input                  TLBr_G,         // TLB read G (Tlbr) (writes to EntryLo) (signal in W1)
    //-- Exception input data --//
    input  [4:0]           Int,            // Raw hardware interrupt requests (writes CauseIP)
    input                  ExcActive,      // An exception (non-NMI) in W1 is ready to process
    input                  NMI,            // Indicator that an active exception is NMI
    input  [4:0]           ExcCode,        // Exception code in W1
    input  [31:0]          ExcVAddr,       // Address that caused an exception (from W1)
    input  [31:0]          RestartPC,      // Restart PC of an exception (from W1)
    input                  IsBDS,          // Exception is a branch delay slot (from W1)
    input                  Eret,           // A current ERET instruction in W1
    //-- Output data --//
    output [(PABITS-8):0]  CacheTag_Out,   // Tag data for 'Store Tag' {PTag[28:2], PState[1:0]}
    output                 ReverseEndian,
    output [3:0]           Index_Out,
    output [3:0]           Random_Out,
    output [15:0]          PageMask_Out,
    output [26:0]          EntryHi_Out,    // {VPN2[31:13], ASID[7:0]}
    output [(PABITS-7):0]  EntryLo0_Out,   // {PFN0[(PABITS-7):6], C0[5:3], D0[2], V0[1], G0[0]}
    output [(PABITS-7):0]  EntryLo1_Out,   // {PFN1[(PABITS-7):6], C1[5:3], D1[2], V1[1], G1[0]}
    output                 Status_BEV_Out, // Boot vectors (used for exception PC)
    output                 Status_ERL_Out, // Error level (used for exception PC)
    output                 Status_EXL_Out, // Exception level (used for exception PC)
    output                 Cause_IV_Out,   // Interrupt Vector (used for exception PC)
    output [31:0]          EPC_Out,        // Exception Program Counter (used for exception PC)
    output [31:0]          ErrorEPC_Out,   // Error Exception Program Counter (used for exception PC)
    output [2:0]           K0,             // Kseg0 cacheability
    output                 Enabled_Int,    // An non-masked interrupt is available (not necessarily active)
    output                 KernelMode,     // The processor is running in kernel mode
    output                 CP0_User        // Access to CP0 is allowed in User mode
    );

    `include "MIPS_Defines.v"

    /*
     Write logic:
       - There are three classes of write operations to CP0 state:
          1. GPR writes (mtc0).
          2. Special instruction writes (cache, tlb{p,r,wi,wr}, eret)
          3. Exceptions and interrupts.

       - All CP0 state is changed in W1.
       - Case 1 depends on W1_Issued and appropriate permissions (CP0_User or KernelMode).
         Currently permissions are detected back in D2 since CP0 state-changing instructions
         are serialized (XOP).
       - Case 2 behaves similarly to case 1.
       - Case 3 depends on W1_Exception and ~W1_Stall, and only writes to BadVAddr, Status, Cause, EPC, and ErrorEPC.
    */


    /*
     MIPS-32 COPROCESSOR 0 (Cp0) REGISTERS

     These are defined in "MIPS32 Architecture for Programmers Volume III:
     The MIPS32 Privileged Resource Architecture" from MIPS Technologies, Inc.
    */

    // Index (Register 0, Select 0)
    wire Index_P;
    wire [3:0] Index_Index;
    wire [31:0] Index = {Index_P, {27{1'b0}}, Index_Index};

    // Random (Register 1, Select 0)
    wire [3:0]  Random_Index;
    wire [31:0] Random = {{28{1'b0}}, Random_Index};

    // EntryLo0 (Register 2, Select 0)
    wire [(37-PABITS):0] EntryLo0_Fill = {(38-PABITS){1'b0}};
    wire [(23-(36-PABITS)):0]  EntryLo0_PFN;
    wire [2:0] EntryLo0_C;
    wire EntryLo0_D;
    wire EntryLo0_V;
    wire EntryLo0_G;
    wire [31:0] EntryLo0 = {EntryLo0_Fill, EntryLo0_PFN, EntryLo0_C, EntryLo0_D, EntryLo0_V, EntryLo0_G};

    // EntryLo1 (Register 3, Select 0)
    wire [(37-PABITS):0] EntryLo1_Fill = {(38-PABITS){1'b0}};
    wire [(23-(36-PABITS)):0]  EntryLo1_PFN;
    wire [2:0] EntryLo1_C;
    wire EntryLo1_D;
    wire EntryLo1_V;
    wire EntryLo1_G;
    wire [31:0] EntryLo1 = {EntryLo1_Fill, EntryLo1_PFN, EntryLo1_C, EntryLo1_D, EntryLo1_V, EntryLo1_G};

    // Context (Register 4, Select 0)
    wire [8:0]  Context_PTEBase;
    wire [18:0] Context_BadVPN2;
    wire [31:0] Context = {Context_PTEBase, Context_BadVPN2, {4{1'b0}}};

    // PageMask (Register 5, Select 0)
    wire [28:13] PageMask_Mask;
    wire [31:0]  PageMask = {{3{1'b0}}, PageMask_Mask, {13{1'b0}}};

    // Wired (Register 6, Select 0)
    wire [3:0]  Wired_Wired;
    wire [31:0] Wired = {{28{1'b0}}, Wired_Wired};

    // BadVAddr (Register 8, Select 0)
    wire [31:0] BadVAddr;

    // Count (Register 9, Select 0)
    wire [31:0] Count;

    // EntryHi (Register 10, Select 0)
    wire [18:0]  EntryHi_VPN2;
    wire [7:0]   EntryHi_ASID;
    wire [31:0]  EntryHi = {EntryHi_VPN2, {5{1'b0}}, EntryHi_ASID};

    // Compare (Register 11, Select 0)
    wire [31:0] Compare;

    // Status (Register 12, Select 0)
    wire [2:0] Status_CU_321 = 3'b000;
    wire Status_CU_0;       // Access Control to CPs, [2]->Cp3, ... [0]->Cp0
    wire Status_RP = 1'b0;
    wire Status_FR = 1'b0;
    wire Status_RE;         // Reverse Endian Memory for User Mode
    wire Status_MX = 1'b0;
    wire Status_PX = 1'b0;
    wire Status_BEV;        // Exception vector locations (0->Norm, 1->Bootstrap)
    wire Status_TS = 1'b0;
    wire Status_SR = 1'b0;  // Soft reset not implemented
    wire Status_NMI;        // Non-Maskable Interrupt
    wire Status_RES = 1'b0;
    wire [1:0] Status_Custom = 2'b00;
    wire [7:0] Status_IM;   // Interrupt mask
    wire Status_KX = 1'b0;
    wire Status_SX = 1'b0;
    wire Status_UX = 1'b0;
    wire Status_UM;         // Base operating mode (0->Kernel, 1->User)
    wire Status_R0 = 1'b0;
    wire Status_ERL;        // Error Level     (0->Normal, 1->Error (reset, NMI))
    wire Status_EXL;        // Exception level (0->Normal, 1->Exception)
    wire Status_IE;         // Interrupt Enable
    wire [31:0] Status = {Status_CU_321, Status_CU_0, Status_RP, Status_FR, Status_RE, Status_MX,
                                 Status_PX, Status_BEV, Status_TS, Status_SR, Status_NMI, Status_RES,
                                 Status_Custom, Status_IM, Status_KX, Status_SX, Status_UX,
                                 Status_UM, Status_R0, Status_ERL, Status_EXL, Status_IE};

    // Cause (Register 13, Select 0)
    wire Cause_BD;                  // Exception occured in Branch Delay
    wire [1:0] Cause_CE;            // CP number for CP Unusable exception
    wire Cause_IV;                  // Indicator of general IV (0->0x180) or special IV (1->0x200)
    wire Cause_WP = 1'b0;
    wire [7:0] Cause_IP;            // Pending HW Interrupt indicator.
    wire [4:0] Cause_ExcCode;       // Description of Exception
    wire [31:0] Cause  = {Cause_BD, 1'b0, Cause_CE, {4{1'b0}}, Cause_IV, Cause_WP,
                                 {6{1'b0}}, Cause_IP, 1'b0, Cause_ExcCode, {2{1'b0}}};

    // Exception Program Counter (Register 14, Select 0)
    wire [31:0] EPC;

    // Processor Identification (Register 15, Select 0)
    wire [7:0] ID_Options = 8'b0101_1000;
    wire [7:0] ID_CID = 8'b0000_0000;
    wire [7:0] ID_PID = 8'b0000_0000;
    wire [7:0] ID_Rev = 8'b0000_0010;
    wire [31:0] PRId = {ID_Options, ID_CID, ID_PID, ID_Rev};

    // Configuration 0 (Register 16, Select 0)
    wire Config_M = 1;
    wire [14:0] Config_Impl = 15'b000_0000_0000_0000;
    wire Config_BE = `Big_Endian;
    wire [1:0] Config_AT = 2'b00;
    wire [2:0] Config_AR = 3'b000;
    wire [2:0] Config_MT = 3'b001;
    wire Config_VI = 1'b0;
    wire [2:0] Config_K0;
    wire [31:0] Config = {Config_M, Config_Impl, Config_BE, Config_AT, Config_AR, Config_MT,
                                 3'b000, Config_VI, Config_K0};

    // Configuration 1 (Register 16, Select 1)
    wire Config1_M = 0;
    wire [5:0] Config1_MMU = 6'b001111; // 16-entry TLB
    wire [2:0] Config1_IS = 3'b010;     // 256 i-cache sets per way (8KB 2-way 16-byte line)
    wire [2:0] Config1_IL = 3'b011;     // 16-byte i-cache line size
    wire [2:0] Config1_IA = 3'b001;     // 2-way i-cache associativity
    wire [2:0] Config1_DS = 3'b000;     // 64 d-cache sets per way (2KB 2-way 16-byte line)
    wire [2:0] Config1_DL = 3'b011;     // 16-byte d-cache line size
    wire [2:0] Config1_DA = 3'b001;     // 2-way d-cache associativity
    wire Config1_C2 = 0;
    wire Config1_MD = 0;
    wire Config1_PC = 0;    // XXX Performance Counters
    wire Config1_WR = 0;    // XXX Watch Registers
    wire Config1_CA = 0;
    wire Config1_EP = 0;
    wire Config1_FP = 0;
    wire [31:0] Config1 = {Config1_M, Config1_MMU, Config1_IS, Config1_IL, Config1_IA,
                                  Config1_DS, Config1_DL, Config1_DA, Config1_C2,
                                  Config1_MD, Config1_PC, Config1_WR, Config1_CA,
                                  Config1_EP, Config1_FP};

    // TagLo Registers (Register 28, Select 0,2)
    wire [22:0] TagLo0_PTag;        // Bits [31:9] of a 36-bit physical address. Low bits ignored when applicable.
    wire [1:0]  TagLo0_PState;      // 00->Invalid, 01->Valid, 10->Valid, 11->Valid+Dirty
    wire        TagLo0_L = 1'b0;    // Line lock (unused)
    wire        TagLo0_F = 1'b0;    // FIFO bit (unused)
    wire        TagLo0_P = 1'b0;    // Parity bit (unused)
    wire [31:0] TagLo0 = {1'b0, TagLo0_PTag, TagLo0_PState, 3'b000, TagLo0_L, TagLo0_F, TagLo0_P};
    wire [31:0] TagLo2 = {32{1'b0}};

    // TagHi Registers (Register 29, Select 0,2)
    wire [3:0]  TagHi0_PTag;        // Bits [35:32] of a 36-bit physical address.
    wire [31:0] TagHi0 = {{28{1'b0}}, TagHi0_PTag};
    wire [31:0] TagHi2 = {32{1'b0}};

    // ErrorEPC (Register 30, Select 0)
    wire [31:0] ErrorEPC;



    // *** Local signals *** //
    reg [31:0] reg_out;

    wire       WriteEnGen;      // General writes to CP0 (mtc0)
    wire       WriteEnExcStd;   // Exception state writes to CP0 (non-NMI)
    wire       WriteEnExcNMI;   // NMI exception state writes to CP0
    wire       EXC_AdEL;        // Address load exception (instruction / data)
    wire       EXC_AdES;        // Address store exception (data)
    wire       EXC_TLB;         // TLB refill/invalid/modified exception (instruction / data)
    wire       EXC_EXL;         // Exceptions that are not reset, soft reset, NMI, or CacheErr
    wire       Int5;            // Timer interrupt

    // *** Top-level assignments *** //
    assign DataOut        = reg_out;

    generate
        if (PABITS > 32)
            assign CacheTag_Out = {TagHi0_PTag[(PABITS-33):0], TagLo0_PTag, TagLo0_PState};
        else
            assign CacheTag_Out = {TagLo0_PTag[(PABITS-10):0], TagLo0_PState};
    endgenerate

    assign ReverseEndian  = Status_RE;
    assign Index_Out      = Index_Index;
    assign Random_Out     = Random_Index;
    assign PageMask_Out   = PageMask_Mask;
    assign EntryHi_Out    = {EntryHi_VPN2, EntryHi_ASID};
    assign EntryLo0_Out   = {EntryLo0_PFN, EntryLo0_C, EntryLo0_D, EntryLo0_V, EntryLo0_G};
    assign EntryLo1_Out   = {EntryLo1_PFN, EntryLo1_C, EntryLo1_D, EntryLo1_V, EntryLo1_G};
    assign K0             = Config_K0;
    assign Enabled_Int    = &{~Status_EXL, ~Status_ERL, Status_IE, |{(Cause_IP[7:0] & Status_IM[7:0])}};
    assign KernelMode     = |{~Status_UM, Status_EXL, Status_ERL};
    assign CP0_User       = Status_CU_0;
    assign Status_BEV_Out = Status_BEV;
    assign Status_ERL_Out = Status_ERL;
    assign Status_EXL_Out = Status_EXL;
    assign Cause_IV_Out   = Cause_IV;
    assign EPC_Out        = EPC;
    assign ErrorEPC_Out   = ErrorEPC;

    // *** Local assignments *** //
    assign WriteEnGen      = W1_Issued; // permission checks occured in an earlier stage (requires instruction serialization)
    assign WriteEnExcStd   = ExcActive & ~NMI; // Must be mutually exclusive with 'WriteEnExcNMI'
    assign WriteEnExcNMI   = ExcActive & NMI;  // Must be mutually exclusive with 'WriteEnExcStd'
    assign EXC_AdEL        = |{ExcCode == `Exc_AdIF, ExcCode == `Exc_AdEL};
    assign EXC_AdES        = |{ExcCode == `Exc_AdES};
    assign EXC_TLB         = |{ExcCode == `Exc_TlbRi, ExcCode == `Exc_TlbIi, ExcCode == `Exc_TlbRLd, ExcCode == `Exc_TlbRSd,
                               ExcCode == `Exc_TlbILd, ExcCode == `Exc_TlbISd, ExcCode == `Exc_TlbMd};
    assign EXC_EXL         = ~|{ExcCode == `Exc_Cachei, ExcCode == `Exc_Cached};  // 'WriteEnExcStd' filters out NMI.
    assign Int5            = (Count == Compare);

    // *** Software reads of CP0 Registers *** //
    always @(*) begin
        case (Rd)
            5'd0    : reg_out <= Index;
            5'd1    : reg_out <= Random;
            5'd2    : reg_out <= EntryLo0;
            5'd3    : reg_out <= EntryLo1;
            5'd4    : reg_out <= Context;
            5'd5    : reg_out <= PageMask;
            5'd6    : reg_out <= Wired;
            5'd8    : reg_out <= BadVAddr;
            5'd9    : reg_out <= Count;
            5'd10   : reg_out <= EntryHi;
            5'd11   : reg_out <= Compare;
            5'd12   : reg_out <= Status;
            5'd13   : reg_out <= Cause;
            5'd14   : reg_out <= EPC;
            5'd15   : reg_out <= PRId;
            5'd16   : reg_out <= (Sel == 3'd0) ? Config : Config1;
            5'd28   : reg_out <= (Sel == 3'd0) ? TagLo0 : TagLo2;
            5'd29   : reg_out <= (Sel == 3'd0) ? TagHi0 : TagHi2;
            5'd30   : reg_out <= ErrorEPC;
            default : reg_out <= {32{1'b0}};
        endcase
    end


    // *** CP0 Register Assignments *** //

    // Index (Register 0, Select 0)
    wire Index_P_en = TLBp_Write;
    wire Index_Index_en = WriteEnGen & (TLBp_Write | (Mtc0 & (Rd == 5'd0) & (Sel == 3'd0)));
    wire [3:0] Index_Index_d = (TLBp_Write) ? TLBp_Index : DataIn[3:0];
    DFF_E #(.WIDTH(1)) IndexP     (.clock(clock), .enable(Index_P_en),     .D(TLBp_NoMatch),  .Q(Index_P));
    DFF_E #(.WIDTH(4)) IndexIndex (.clock(clock), .enable(Index_Index_en), .D(Index_Index_d), .Q(Index_Index));

    // Random (Register 1, Select 0)
    wire Random_Index_en1 = (WriteEnGen & Mtc0 & (Rd == 5'd6) & (Sel == 3'd0)) | (Random_Index == Wired_Wired);
    wire Random_Index_en2 = W1_Issued;
    wire Random_Index_en  = |{Random_Index_en1, Random_Index_en2};
    wire [3:0] Random_Index_d = (Random_Index_en1) ? 4'd15 : (Random_Index - 1);
    DFF_SRE #(.WIDTH(4), .INIT(4'd15)) RandomIndex (.clock(clock), .reset(reset), .enable(Random_Index_en), .D(Random_Index_d), .Q(Random_Index));

    // EntryLo0 (Register 2, Select 0)
    wire EntryLo0_en    = WriteEnGen & (TLBr_Write | (Mtc0 & (Rd == 5'd2) & (Sel == 3'd0)));
    wire [(23-(36-PABITS)):0] EntryLo0_PFN_d = (TLBr_Write) ? TLBr_PFN0[(23-(36-PABITS)):0] : DataIn[(29-(36-PABITS)):6];
    wire [2:0] EntryLo0_C_d = (TLBr_Write) ? TLBr_C0 : DataIn[5:3];
    wire EntryLo0_D_d   = (TLBr_Write) ? TLBr_D0 : DataIn[2];
    wire EntryLo0_V_d   = (TLBr_Write) ? TLBr_V0 : DataIn[1];
    wire EntryLo0_G_d   = (TLBr_Write) ? TLBr_G  : DataIn[0];
    DFF_E #(.WIDTH(24-(36-PABITS))) EntryLo0PFN (.clock(clock), .enable(EntryLo0_en), .D(EntryLo0_PFN_d), .Q(EntryLo0_PFN));
    DFF_E #(.WIDTH(3))              EntryLo0C   (.clock(clock), .enable(EntryLo0_en), .D(EntryLo0_C_d),   .Q(EntryLo0_C));
    DFF_E #(.WIDTH(1))              EntryLo0D   (.clock(clock), .enable(EntryLo0_en), .D(EntryLo0_D_d),   .Q(EntryLo0_D));
    DFF_E #(.WIDTH(1))              EntryLo0V   (.clock(clock), .enable(EntryLo0_en), .D(EntryLo0_V_d),   .Q(EntryLo0_V));
    DFF_E #(.WIDTH(1))              EntryLo0G   (.clock(clock), .enable(EntryLo0_en), .D(EntryLo0_G_d),   .Q(EntryLo0_G));

    // EntryLo1 (Register 3, Select 0)
    wire EntryLo1_en    = WriteEnGen & (TLBr_Write | (Mtc0 & (Rd == 5'd3) & (Sel == 3'd0)));
    wire [(23-(36-PABITS)):0] EntryLo1_PFN_d = (TLBr_Write) ? TLBr_PFN1[(23-(36-PABITS)):0] : DataIn[(29-(36-PABITS)):6];
    wire [2:0] EntryLo1_C_d = (TLBr_Write) ? TLBr_C1 : DataIn[5:3];
    wire EntryLo1_D_d   = (TLBr_Write) ? TLBr_D1 : DataIn[2];
    wire EntryLo1_V_d   = (TLBr_Write) ? TLBr_V1 : DataIn[1];
    wire EntryLo1_G_d   = (TLBr_Write) ? TLBr_G  : DataIn[0];
    DFF_E #(.WIDTH(24-(36-PABITS))) EntryLo1PFN (.clock(clock), .enable(EntryLo1_en), .D(EntryLo1_PFN_d), .Q(EntryLo1_PFN));
    DFF_E #(.WIDTH(3))              EntryLo1C   (.clock(clock), .enable(EntryLo1_en), .D(EntryLo1_C_d),   .Q(EntryLo1_C));
    DFF_E #(.WIDTH(1))              EntryLo1D   (.clock(clock), .enable(EntryLo1_en), .D(EntryLo1_D_d),   .Q(EntryLo1_D));
    DFF_E #(.WIDTH(1))              EntryLo1V   (.clock(clock), .enable(EntryLo1_en), .D(EntryLo1_V_d),   .Q(EntryLo1_V));
    DFF_E #(.WIDTH(1))              EntryLo1G   (.clock(clock), .enable(EntryLo1_en), .D(EntryLo1_G_d),   .Q(EntryLo1_G));

    // Context (Register 4, Select 0)
    assign Context_BadVPN2 = BadVAddr[31:13];
    wire Context_PTEBase_en = WriteEnGen & Mtc0 & (Rd == 5'd4) & (Sel == 3'd0);
    DFF_E #(.WIDTH(9)) ContextPTEBase (.clock(clock), .enable(Context_PTEBase_en), .D(DataIn[31:23]), .Q(Context_PTEBase));

    // PageMask (Register 5, Select 0)
    wire PageMask_Mask_en = WriteEnGen & (TLBr_Write | (Mtc0 & (Rd == 5'd5) & (Sel == 3'd0)));
    wire [15:0] PageMask_Mask_d = (TLBr_Write) ? TLBr_Mask : DataIn[28:13];
    DFF_E #(.WIDTH(16)) PageMaskMask (.clock(clock), .enable(PageMask_Mask_en), .D(PageMask_Mask_d), .Q(PageMask_Mask));

    // Wired (Register 6, Select 0)
    wire Wired_Wired_en = WriteEnGen & Mtc0 & (Rd == 5'd6) & (Sel == 3'd0);
    DFF_SRE #(.WIDTH(4)) WiredWired (.clock(clock), .reset(reset), .enable(Wired_Wired_en), .D(DataIn[3:0]), .Q(Wired_Wired));

    // BadVAddr (Register 8, Select 0)
    wire BadVAddr_en = |{EXC_AdEL, EXC_AdES, EXC_TLB} & WriteEnExcStd;
    DFF_E #(.WIDTH(32)) BadVAddrR (.clock(clock), .enable(BadVAddr_en), .D(ExcVAddr), .Q(BadVAddr));

    // Count (Register 9, Select 0)
    wire Count_en = 1'b1;
    wire [31:0] Count_d  = (WriteEnGen & Mtc0 & (Rd == 5'd9) & (Sel == 3'd0)) ? DataIn : Count + 1;
    DFF_E #(.WIDTH(32)) CountR (.clock(clock), .enable(Count_en), .D(Count_d), .Q(Count));

    // EntryHi (Register 10, Select 0)
    wire EntryHi_en = WriteEnGen & (TLBr_Write | (Mtc0 & (Rd == 5'd10) & (Sel == 3'd0)));
    wire [18:0] EntryHi_VPN2_d = (TLBr_Write) ? TLBr_VPN2 : DataIn[31:13];
    wire [7:0]  EntryHi_ASID_d = (TLBr_Write) ? TLBr_ASID : DataIn[7:0];
    DFF_E #(.WIDTH(19)) EntryHiVPN2 (.clock(clock), .enable(EntryHi_en), .D(EntryHi_VPN2_d), .Q(EntryHi_VPN2));
    DFF_E #(.WIDTH(8))  EntryHiASID (.clock(clock), .enable(EntryHi_en), .D(EntryHi_ASID_d), .Q(EntryHi_ASID));

    // Compare (Register 11, Select 0)
    wire Compare_en = WriteEnGen & Mtc0 & (Rd == 5'd11) & (Sel == 3'd0);
    DFF_E #(.WIDTH(32)) CompareR (.clock(clock), .enable(Compare_en), .D(DataIn), .Q(Compare));

    // Status (Register 12, Select 0)
    wire StatusGen_en   = WriteEnGen & Mtc0 & (Rd == 5'd12) & (Sel == 3'd0);
    wire Status_BEV1_en = StatusGen_en;
    wire Status_BEV2_en = WriteEnExcNMI;
    wire Status_BEV_en  = |{Status_BEV1_en, Status_BEV2_en};
    wire Status_BEV_d   = (Status_BEV2_en) ? 1'b1 : DataIn[22];
    wire Status_NMI_en  = WriteEnExcNMI;
    wire Status_NMI_d   = (Status_NMI_en) ? 1'b1 : DataIn[19];
    wire Status_ERL1_en = StatusGen_en;
    wire Status_ERL2_en = WriteEnExcNMI;
    wire Status_ERL3_en = &{Status_ERL, Eret, WriteEnGen};
    wire Status_ERL_en  = |{Status_ERL1_en, Status_ERL2_en, Status_ERL3_en};
    wire Status_ERL_d   = (Status_ERL2_en) ? 1'b1 : ((Status_ERL1_en) ? DataIn[2] : 1'b0);
    wire Status_EXL1_en = StatusGen_en;
    wire Status_EXL2_en = WriteEnExcStd & EXC_EXL;
    wire Status_EXL3_en = &{~Status_ERL, Eret, WriteEnGen};
    wire Status_EXL_en  = |{Status_EXL1_en, Status_EXL2_en, Status_EXL3_en};
    wire Status_EXL_d   = (Status_EXL2_en) ? 1'b1 : ((Status_EXL1_en) ? DataIn[1] : 1'b0);
    DFF_E   #(.WIDTH(1))              StatusCU  (.clock(clock),                .enable(StatusGen_en),  .D(DataIn[28]),   .Q(Status_CU_0));
    DFF_E   #(.WIDTH(1))              StatusRE  (.clock(clock),                .enable(StatusGen_en),  .D(DataIn[25]),   .Q(Status_RE));
    DFF_SRE #(.WIDTH(1), .INIT(1'b1)) StatusBEV (.clock(clock), .reset(reset), .enable(Status_BEV_en), .D(Status_BEV_d), .Q(Status_BEV));
    DFF_SRE #(.WIDTH(1), .INIT(1'b0)) StatusNMI (.clock(clock), .reset(reset), .enable(Status_BEV_en), .D(Status_NMI_d), .Q(Status_NMI));
    DFF_E   #(.WIDTH(8))              StatusIM  (.clock(clock),                .enable(StatusGen_en),  .D(DataIn[15:8]), .Q(Status_IM));
    DFF_E   #(.WIDTH(1))              StatusUM  (.clock(clock),                .enable(StatusGen_en),  .D(DataIn[4]),    .Q(Status_UM));
    DFF_SRE #(.WIDTH(1), .INIT(1'b1)) StatusERL (.clock(clock), .reset(reset), .enable(Status_ERL_en), .D(Status_ERL_d), .Q(Status_ERL));
    DFF_E   #(.WIDTH(1))              StatusEXL (.clock(clock),                .enable(Status_EXL_en), .D(Status_EXL_d), .Q(Status_EXL));
    DFF_E   #(.WIDTH(1))              StatusIE  (.clock(clock),                .enable(StatusGen_en),  .D(DataIn[0]),    .Q(Status_IE));

    // Cause (Register 13, Select 0)
    wire Cause_BD_en      = WriteEnExcStd & ~Status_EXL;
    wire Cause_CE_en      = WriteEnExcStd & |{ExcCode == `Exc_CpU0, ExcCode == `Exc_CpU1, ExcCode == `Exc_CpU2, ExcCode == `Exc_CpU3};
    wire [1:0] Cause_CE_d = (ExcCode == `Exc_CpU3) ? 2'd3 : ((ExcCode == `Exc_CpU2) ? 2'd2 : ((ExcCode == `Exc_CpU1) ? 2'd1 : 2'd0));
    wire CauseGen_en      = WriteEnGen & Mtc0 & (Rd == 5'd13) & (Sel == 3'd0);
    wire Cause_IP71_en    = WriteEnGen & Mtc0 & (Rd == 5'd11) & (Sel == 3'd0);
    wire Cause_IP72_en    = Int5;
    wire Cause_IP7_en     = |{Cause_IP71_en, Cause_IP72_en};
    wire Cause_IP7_d      = (Cause_IP71_en) ? 1'b0 : 1'b1;
    wire Cause_ExcCode_en = WriteEnExcStd;
    reg  [4:0] Cause_ExcCode_d;
    DFF_E #(.WIDTH(1)) CauseBD      (.clock(clock), .enable(Cause_BD_en),      .D(IsBDS),           .Q(Cause_BD));
    DFF_E #(.WIDTH(2)) CauseCE      (.clock(clock), .enable(Cause_CE_en),      .D(Cause_CE_d),      .Q(Cause_CE));
    DFF_E #(.WIDTH(1)) CauseIV      (.clock(clock), .enable(CauseGen_en),      .D(DataIn[23]),      .Q(Cause_IV));
    DFF_E #(.WIDTH(1)) CauseIP7     (.clock(clock), .enable(Cause_IP7_en),     .D(Cause_IP7_d),     .Q(Cause_IP[7]));
    DFF_E #(.WIDTH(5)) CauseIP62    (.clock(clock), .enable(1'b1),             .D(Int),             .Q(Cause_IP[6:2]));
    DFF_E #(.WIDTH(2)) CauseIP10    (.clock(clock), .enable(CauseGen_en),      .D(DataIn[9:8]),     .Q(Cause_IP[1:0]));
    DFF_E #(.WIDTH(5)) CauseExcCode (.clock(clock), .enable(Cause_ExcCode_en), .D(Cause_ExcCode_d), .Q(Cause_ExcCode));

    always @(*) begin
        case (ExcCode)
            `Exc_None:      Cause_ExcCode_d <= 5'd31;   // Reserved
            `Exc_Int:       Cause_ExcCode_d <= 5'd0;    // Int
            `Exc_AdIF:      Cause_ExcCode_d <= 5'd4;    // AdEL
            `Exc_TlbRi:     Cause_ExcCode_d <= 5'd2;    // TLBL
            `Exc_TlbIi:     Cause_ExcCode_d <= 5'd2;    // TLBL
            `Exc_Cachei:    Cause_ExcCode_d <= 5'd30;   // CacheErr
            `Exc_Busi:      Cause_ExcCode_d <= 5'd6;    // IBE
            `Exc_CpU0:      Cause_ExcCode_d <= 5'd11;   // CpU
            `Exc_CpU1:      Cause_ExcCode_d <= 5'd11;   // CpU
            `Exc_CpU2:      Cause_ExcCode_d <= 5'd11;   // CpU
            `Exc_CpU3:      Cause_ExcCode_d <= 5'd11;   // CpU
            `Exc_RI:        Cause_ExcCode_d <= 5'd10;   // RI
            `Exc_Sys:       Cause_ExcCode_d <= 5'd8;    // Sys
            `Exc_Bp:        Cause_ExcCode_d <= 5'd9;    // Bp
            `Exc_Tr:        Cause_ExcCode_d <= 5'd13;   // Tr
            `Exc_Ov:        Cause_ExcCode_d <= 5'd12;   // Ov
            `Exc_AdEL:      Cause_ExcCode_d <= 5'd4;    // AdEL
            `Exc_AdES:      Cause_ExcCode_d <= 5'd5;    // AdES
            `Exc_TlbRLd:    Cause_ExcCode_d <= 5'd2;    // TLBL
            `Exc_TlbRSd:    Cause_ExcCode_d <= 5'd3;    // TLBS
            `Exc_TlbILd:    Cause_ExcCode_d <= 5'd2;    // TLBL
            `Exc_TlbISd:    Cause_ExcCode_d <= 5'd3;    // TLBS
            `Exc_TlbMd:     Cause_ExcCode_d <= 5'd1;    // Mod
            `Exc_Cached:    Cause_ExcCode_d <= 5'd30;   // CacheErr
            `Exc_Busd:      Cause_ExcCode_d <= 5'd7;    // DBE
            default:        Cause_ExcCode_d <= 5'd31;   // Reserved
        endcase
    end

    // Exception Program Counter (Register 14, Select 0)
    wire EPC1_en      = WriteEnExcStd & ~Status_EXL;
    wire EPC2_en      = WriteEnGen & Mtc0 & (Rd == 5'd14) & (Sel == 3'd0);
    wire EPC_en       = |{EPC1_en, EPC2_en};
    wire [31:0] EPC_d = (EPC1_en) ? RestartPC : DataIn;
    DFF_E #(.WIDTH(32)) EPCR (.clock(clock), .enable(EPC_en), .D(EPC_d), .Q(EPC));

    // Configuration 0 (Register 16, Select 0)
    wire Config_K0_en = WriteEnGen & Mtc0 & (Rd == 5'd16) & (Sel == 3'd0);
    DFF_E #(.WIDTH(3)) CONFIGK0 (.clock(clock), .enable(Config_K0_en), .D(DataIn[2:0]), .Q(Config_K0));

    // TagLo Registers (Register 28, Select 0,2)
    wire TagLo_en = WriteEnGen & Mtc0 & (Rd == 5'd28) & (Sel == 3'd0);
    DFF_E #(.WIDTH(23)) TagLoPTag   (.clock(clock), .enable(TagLo_en), .D(DataIn[30:8]), .Q(TagLo0_PTag));
    DFF_E #(.WIDTH(2))  TagLoPState (.clock(clock), .enable(TagLo_en), .D(DataIn[7:6]),  .Q(TagLo0_PState));

    // TagHi Registers (Register 29, Select 0,2)
    wire TagHi0_en = WriteEnGen & Mtc0 & (Rd == 5'd29) & (Sel == 3'd0);
    DFF_E #(.WIDTH(4)) TagHi0PTag (.clock(clock), .enable(TagHi0_en), .D(DataIn[3:0]), .Q(TagHi0_PTag));

    // ErrorEPC (Register 30, Select 0)
    wire ErrorEPC1_en = WriteEnExcNMI;
    wire ErrorEPC2_en = WriteEnGen & Mtc0 & (Rd == 5'd30) & (Sel == 3'd0);
    wire ErrorEPC_en  = |{ErrorEPC1_en, ErrorEPC2_en};
    wire [31:0] ErrorEPC_d = (ErrorEPC1_en) ? RestartPC : DataIn;
    DFF_E #(.WIDTH(32)) ErrorEPCR (.clock(clock), .enable(ErrorEPC_en), .D(ErrorEPC_d), .Q(ErrorEPC));

endmodule

