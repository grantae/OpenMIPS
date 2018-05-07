`timescale 1ns / 1ps
/*
 * File         : Hazard_Detection.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Hazard Detection and Forward Control. This is the glue that allows a
 *   pipelined processor to operate efficiently and correctly in the presence
 *   of data, structural, and control hazards. For each pipeline stage, it
 *   detects whether that stage requires data that is still in the pipeline,
 *   and whether that data may be forwarded or if the pipeline must be stalled.
 *
 */
module Hazard_Detection(
    input  [9:0]  DP_Hazards,       // Data requirements from pipeline stages (D2, X1, M1)
    input         D1_F2Issued,      // D1 is a programmed instruction that was not canceled in a prior stage
    input         D2_D1Issued,      // D2 is a programmed instruction that was not canceled in a prior stage
    input         X1_D2Issued,      // X1 is a programmed instruction that was not canceled in a prior stage
    input         M1_X1Issued,      // M1 is a programmed instruction that was not canceled in a prior stage
    input         M2_M1Issued,      // M2 is a programmed instruction that was not canceled in a prior stage
    input         W1_M2Issued,      // W1 is a programmed instruction that was not canceled in a prior stage
    input  [4:0]  D1_Rs,            // D1 read register 1
    input  [4:0]  D1_Rt,            // D1 read register 2
    input  [4:0]  D2_Rs,            // D2 read register 1
    input  [4:0]  D2_Rt,            // D2 read register 2
    input  [4:0]  X1_Rs,            // X1 read register 1
    input  [4:0]  X1_Rt,            // X1 read register 2
    input  [4:0]  M1_Rt,            // M1 read register 2
    input  [4:0]  X1_RtRd,          // X1 write register
    input  [4:0]  M1_RtRd,          // M1 write register
    input  [4:0]  M2_RtRd,          // M2 write register
    input  [4:0]  W1_RtRd,          // W1 write register
    input         X1_RegWrite,      // X1 write register control
    input         M1_RegWrite,      // M1 write register control
    input         M2_RegWrite,      // M2 write register control
    input         W1_RegWrite,      // W1 write register control
    input         M1_MemRead,       // M1 read memory control
    input         M1_MemWrite,      // M1 write memory control
    input         M2_MemRead,       // M2 read memory control
    input         M2_MemWrite,      // M2 write memory control
    input         X1_HiLoRead,      // X1 Hi/Lo read control
    input         M1_HiLoWrite,     // M1 Hi/Lo write control
    input         M2_HiLoWrite,     // M2 Hi/Lo write control
    input         W1_HiLoWrite,     // W1 Hi/Lo write control
    input         W1_XOP,           // Exclusive instruction in W1
    input         F2_Cache_Stall,   // Instruction cache miss
    input         F2_Cache_Blocked, // Instruction cache busy and not cancellable
    input         M2_Cache_Stall,   // Data cache miss
    input         D2_NextIsBDS,     // A jump or branch is in D2
    input         D2_Branch,        // A jump or branch is in D2 and will be taken
    input         ALU_MulBusy,      // The multicycle multiply/addsub unit is busy
    input         ALU_DivBusy,      // The multicycle divide unit is busy
    input         W1_ExcDetected,   // An exception/NMI in W1 which is not yet active
    input         W1_ICacheOpEn,    // Special forwarding for i-cache operations
    output        D1_RsFwdSel,      // Forward mux control for Rs in D1
    output        D1_RtFwdSel,      // Forward mux control for Rt in D1
    output [1:0]  D2_RsFwdSel,      // Forward mux control for Rs in D2
    output [1:0]  D2_RtFwdSel,      // Forward mux control for Rt in D2
    output [1:0]  X1_RsFwdSel,      // Forward mux control for Rs in X1
    output [1:0]  X1_RtFwdSel,      // Forward mux control for Rt in X1
    output [1:0]  M1_RtFwdSel,      // Forward mux control for Rt in M1
    output        F1_Stall,         // Stall control for F1
    output        F2_NonMem_Stall,  // Stall control for I-Cache
    output        F2_Stall,         // Stall control for F2
    output        D1_Stall,         // Stall control for D1
    output        D2_Stall,         // Stall control for D2
    output        X1_Stall,         // Stall control for X1
    output        M1_Stall,         // Stall control for M1
    output        M2_NonMem_Stall,  // Stall control for D-Cache
    output        M2_Stall,         // Stall control for M2
    output        W1_NonMem_Stall,  // Stall caused by e.g., the ALU
    output        W1_Stall,         // Stall control for W1
    output        F1_Flush,         // Flush control for F1
    output        F2_Flush,         // Flush control for F2
    output        D1_Flush,         // Flush control for D1
    output        D2_Flush,         // Flush control for D2
    output        X1_Flush,         // Flush control for X1
    output        M1_Flush,         // Flush control for M1
    output        M2_Flush,         // Flush control for M2
    output        W1_Flush_Pending, // Pre-W1 flush indicator to block new d-cache operations
    output        W1_Flush          // Flush control for W1
    );

    /* Hazard and Forward Detection
     *
     * Most instructions read from one or more general-purpose registers (GPRs).
     * Normally this occurs in the D1 stage. However, frequently the register file
     * in the D1 stage is stale when one or more forward stages in the pipeline
     * (D2, X1, M1, M2, or W1) contains an instruction which will eventually update
     * it but has not yet done so.
     *
     * A hazard condition is created when a forward pipeline stage is set to write
     * the same register that a current pipeline stage (e.g. in D1) needs to read.
     * The solution is to stall the current stage (and effectively all stages behind
     * it) or bypass (forward) the data from forward stages. Fortunately forwarding
     * works for most combinations of instructions.
     *
     * Hazard and Forward conditions are handled based on two simple rules:
     * "Wants" and "Needs." If an instruction "wants" data in a certain pipeline
     * stage, and that data is available further along in the pipeline, it will
     * be forwarded. If it "needs" data and the data is not yet available for forwarding,
     * the pipeline stage stalls. If it does not want or need data in a certain
     * stage, forwarding is disabled and a stall will not occur. This is important
     * for instructions which insert custom data, such as jal or movz.
     *
     * Data is forwarded to pipeline stage registers even if they are currently stalled.
     * This prevents "false forwarding" conditions where a stalled stage can no longer
     * obtain valid data because it has passed the register file (D1) and stalled long
     * enough for forward stages to complete and write their data to the register file.
     *
     * Currently, "Want" and "Need" conditions are defined for both Rs data and Rt
     * data (the two read registers in MIPS), and these conditions exist in the
     * D2, X1, and M1 pipeline stages. This is a total of twelve condition bits.
     * This module assumes that if a forward stage declares a need bit, all previous
     * stages declare a want bit (e.g., needing Rs in X1 -> wanting Rs in D2).
     *
     * Forwarding is only enabled for GPRs. Instructions which commit to privileged
     * registers or state (mtc0, tlb{p,r,wi,wr}, cache, eret) are serialized in
     * the pipeline. Instructions which write to HI/LO are not serialized, but will
     * stall if a previous commit to HI/LO is not yet complete.
     *
     * A unique GPR forwarding condition exists with store instructions, which
     * don't need the "Rt" data until the M1 stage. Because data doesn't change in
     * M2 or W1, and these are the only stages following M1, forwarding is *always*
     * possible from M2/W1 to M1. This unit handles this situation, and a condition
     * bit is not needed.
     *
     * When data is needed from the M1/M2 stages by a previous stage (D2 or X), the
     * decision to forward or stall is based on whether M1/M2 is accessing memory
     * (stall) or not (forward). Normally store instructions don't write to registers
     * and thus are never needed for a data dependence, so the signal 'MEM_MemRead'
     * is sufficient to determine. Because of the Store Conditional instruction,
     * however, 'MEM_MemWrite' must also be considered because it writes to a register.
     *
     * TODO: XOP flushing prior stages.
     */

    /*
     * XXX TODO: What happens when conditional instructions cancel, like movn failing?
     * A dependent stage could have captured the invalid forward data. Well D<-X should stall
     * anyway, and by M1 we know if issued/reg_write or not. So worst case you stall for nothing.
     * MAKE SURE M1_X1Issued would be low by this point.
     */

     // TODO: Branch logic early stage flushes

    /*
     * System Control Hazards:
     *
     * Writes to CP0 cause a plethora of hazards to the processor (see MIPS32 Volume III).
     * For example, even a regular instruction fetch is dependent on a mtc0 instruction if it's
     * changing the ASID. One way to handle this is to give software the responsibility to avoid
     * these situations. The most conservative option is to use full hardware interlocking when
     * such conditions arise.
     *
     * This processor implements full hardware interlocking. However, it does so at a coarse
     * granularity which means ANY write to CP0 is serialized in the pipeline. This effectively
     * causes this group of instructions (mtc0, cache, eret, tlbp, tlbr, tlbwi, tlbwr) to take 9
     * cycles which can have significant performance implications with frequent CP0 writing.
     *
     * Interlocking is implemented as follows: Exclusive Operations (XOPs) are defined as writes
     * to CP0 which must be serialized. When W1 has a valid XOP, all prior pipeline stages are
     * flushed. If the XOP is not eret, the PC latches the XOP restart PC and the F1 stage is
     * tagged to indicate that the second fetch should not be executed. This behavior is used
     * instead of latching XOP+4 to allow certain XOPs to be in branch delay slots.
     *
     * XXX TODO: W1 must wait for external stalls like I$ D$.
     *
     */

    /*
     * ALU Long Operations:
     *
     * - HILO computations are these instructions: div,divu,mul,mult,multu,madd,maddu,msub,msubu.
     * - They begin in X1 where GPR data and possibly HILO will be read.
     * - If any input is not available in X1, X1 will stall.
     * - If any other HILO-writing instruction is further in the pipeline, X1 will stall.
     * - When these instructions reach W1 they are written unless the ALU/DSP is still busy in which
     *   case W1 is stalled.
     * - Reads from HILO--including mfhi,mflo and several above--also occur in X1, stalling if needed
     *   (i.e., another HILO-writing instruction is further in the pipeline).
     * - The 'mul' instruction is a special case where HILO and a GPR are written. It is muxed into W1
     *   alongside the HILO write data. All other reads from HILO occur directly from the register in X1.
     *
     */

    /*
     * Note on pipeline flushes and the caches:
     *
     * When the pipeline needs to flush (interrupt, exception, XOP, etc.) the d-cache can be cancelled
     * but the i-cache may be in the middle of a long read. It is horrible for timing to make the flush
     * wait on the i-cache ready signal (it depends on the TLB and others) so instead we use the 'blocked'
     * signal from the i-cache which indicates that the cache cannot be stopped by setting the physical
     * address to invalid. This is mostly the same as !ready but can be 0 in the tag check state, even if
     * the cache has missed.
     */

    wire WantRsByD2 = DP_Hazards[9];
    wire NeedRsByD2 = DP_Hazards[8];
    wire WantRtByD2 = DP_Hazards[7];
    wire NeedRtByD2 = DP_Hazards[6];
    wire WantRsByX1 = DP_Hazards[5];
    wire NeedRsByX1 = DP_Hazards[4];
    wire WantRtByX1 = DP_Hazards[3];
    wire NeedRtByX1 = DP_Hazards[2];
    wire WantRtByM1 = DP_Hazards[1];
    wire NeedRtByM1 = DP_Hazards[0];

    // Forwarding should not happen when the src/dst register is $zero
    wire X1_RtRd_NZ = |{X1_RtRd};
    wire M1_RtRd_NZ = |{M1_RtRd};
    wire M2_RtRd_NZ = |{M2_RtRd};
    wire W1_RtRd_NZ = |{W1_RtRd};

    /* Forward logic with Issued:
     *  Rx:0 Tx:0   : Forwarding doesn't matter, should never stall
     *  Rx:0 Tx:1   : Forwarding doesn't matter, should never stall
     *  Rx:1 Tx:0   : No forward, No stall
     *  Rx:1 Tx:1   : Forward, Stall
     *
     *  00 -> x0
     *  01 -> x0
     *  10 -> 00
     *  11 -> 11
     *
     *  So only 1 no-fwd case. Does it really matter? If ~Issued caused by exception it's okay
     *  since Rx will be flushed too. If currently stalled, okay since next cycle Rx will also
     *  get it. If pipeline bubble, can just use register ~Issued since computed doesn't matter.
     */

    // D1 Register Matches
    wire Rs_D1W1_Match = (D1_Rs == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & D1_F2Issued & W1_M2Issued;
    wire Rt_D1W1_Match = (D1_Rt == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & D1_F2Issued & W1_M2Issued;
    // D2 Register Matches
    wire Rs_D2X1_Match = (D2_Rs == X1_RtRd) & X1_RtRd_NZ & X1_RegWrite & D2_D1Issued & X1_D2Issued;
    wire Rt_D2X1_Match = (D2_Rt == X1_RtRd) & X1_RtRd_NZ & X1_RegWrite & D2_D1Issued & X1_D2Issued;
    wire Rs_D2M1_Match = (D2_Rs == M1_RtRd) & M1_RtRd_NZ & M1_RegWrite & D2_D1Issued & M1_X1Issued;
    wire Rt_D2M1_Match = (D2_Rt == M1_RtRd) & M1_RtRd_NZ & M1_RegWrite & D2_D1Issued & M1_X1Issued;
    wire Rs_D2M2_Match = (D2_Rs == M2_RtRd) & M2_RtRd_NZ & M2_RegWrite & D2_D1Issued & M2_M1Issued;
    wire Rt_D2M2_Match = (D2_Rt == M2_RtRd) & M2_RtRd_NZ & M2_RegWrite & D2_D1Issued & M2_M1Issued;
    wire Rs_D2W1_Match = (D2_Rs == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & D2_D1Issued & W1_M2Issued;
    wire Rt_D2W1_Match = (D2_Rt == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & D2_D1Issued & W1_M2Issued;
    // X1 Register Matches
    wire Rs_X1M1_Match = (X1_Rs == M1_RtRd) & M1_RtRd_NZ & M1_RegWrite & X1_D2Issued & M1_X1Issued;
    wire Rt_X1M1_Match = (X1_Rt == M1_RtRd) & M1_RtRd_NZ & M1_RegWrite & X1_D2Issued & M1_X1Issued;
    wire Rs_X1M2_Match = (X1_Rs == M2_RtRd) & M2_RtRd_NZ & M2_RegWrite & X1_D2Issued & M2_M1Issued;
    wire Rt_X1M2_Match = (X1_Rt == M2_RtRd) & M2_RtRd_NZ & M2_RegWrite & X1_D2Issued & M2_M1Issued;
    wire Rs_X1W1_Match = (X1_Rs == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & X1_D2Issued & W1_M2Issued;
    wire Rt_X1W1_Match = (X1_Rt == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & X1_D2Issued & W1_M2Issued;
    // M1 Write Data Matches
    wire Rt_M1M2_Match = (M1_Rt == M2_RtRd) & M2_RtRd_NZ & M2_RegWrite & M1_X1Issued & M2_M1Issued;
    wire Rt_M1W1_Match = (M1_Rt == W1_RtRd) & W1_RtRd_NZ & W1_RegWrite & M1_X1Issued & W1_M2Issued;

    // D1 needs data from W1 : Forward
    wire D1_Fwd_1   = Rs_D1W1_Match;
    wire D1_Fwd_2   = Rt_D1W1_Match;
    // D2 needs data from X1 : Stall
    wire D2_Stall_1 = (Rs_D2X1_Match & NeedRsByD2);
    wire D2_Stall_2 = (Rt_D2X1_Match & NeedRtByD2);
    // D2 needs data from M1 : Stall if mem access or mul
    wire D2_Stall_3 = (Rs_D2M1_Match & NeedRsByD2 & (M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    wire D2_Stall_4 = (Rt_D2M1_Match & NeedRtByD2 & (M1_MemRead | M1_MemWrite));
    // D2 wants/needs data from M1 : Forward if not mem access
    wire D2_Fwd_1   = (Rs_D2M1_Match & (WantRsByD2 | NeedRsByD2) & ~(M1_MemRead | M1_MemWrite | M1_HiLoWrite));    // XXX can maybe kill memread etc. conditions if don't-care
    wire D2_Fwd_2   = (Rt_D2M1_Match & (WantRtByD2 | NeedRtByD2) & ~(M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    // D2 needs data from M2 : Stall if mem access or mul
    wire D2_Stall_5 = (Rs_D2M2_Match & NeedRsByD2 & (M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    wire D2_Stall_6 = (Rt_D2M2_Match & NeedRtByD2 & (M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // D2 wants/needs data from M2 : Forward if not mem access
    wire D2_Fwd_3   = (Rs_D2M2_Match & (WantRsByD2 | NeedRsByD2) & ~(M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    wire D2_Fwd_4   = (Rt_D2M2_Match & (WantRtByD2 | NeedRtByD2) & ~(M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // D2 wants/needs data from W1 : Forward
    wire D2_Fwd_5   = (Rs_D2W1_Match & (WantRsByD2 | NeedRsByD2));
    wire D2_Fwd_6   = (Rt_D2W1_Match & (WantRtByD2 | NeedRtByD2));
    // D2 needs the W1 ALU result as an effective address for an i-cache instruction : Forward
    wire D2_Fwd_7   = W1_ICacheOpEn;
    // X1 needs data from M1 : Stall if mem access or mul
    wire X1_Stall_1 = (Rs_X1M1_Match & NeedRsByX1 & (M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    wire X1_Stall_2 = (Rt_X1M1_Match & NeedRtByX1 & (M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    // X1 wants/needs data from M1 : Forward if not mem access
    wire X1_Fwd_1   = (Rs_X1M1_Match & (WantRsByX1 | NeedRsByX1) & ~(M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    wire X1_Fwd_2   = (Rt_X1M1_Match & (WantRtByX1 | NeedRtByX1) & ~(M1_MemRead | M1_MemWrite | M1_HiLoWrite));
    // X1 needs data from M2 : Stall if mem access or mul
    wire X1_Stall_3 = (Rs_X1M2_Match & NeedRsByX1 & (M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    wire X1_Stall_4 = (Rt_X1M2_Match & NeedRtByX1 & (M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // X1 wants/needs data from M2 : Forward if not mem access
    wire X1_Fwd_3   = (Rs_X1M2_Match & (WantRsByX1 | NeedRsByX1) & ~(M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    wire X1_Fwd_4   = (Rt_X1M2_Match & (WantRtByX1 | NeedRtByX1) & ~(M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // X1 wants/needs data from W1 : Forward
    wire X1_Fwd_5   = (Rs_X1W1_Match & (WantRsByX1 | NeedRsByX1));
    wire X1_Fwd_6   = (Rt_X1W1_Match & (WantRtByX1 | NeedRtByX1));
    // M1 needs data from M2 : Stall if mem access
    wire M1_Stall_1 = (Rt_M1M2_Match & NeedRtByM1 & (M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // M1 wants/needs data from M2 : Forward if not mem access
    wire M1_Fwd_2   = (Rt_M1M2_Match & (WantRtByM1 | NeedRtByM1) & ~(M2_MemRead | M2_MemWrite | M2_HiLoWrite));
    // M1 wants/needs data from W1 : Forward
    wire M1_Fwd_4   = (Rt_M1W1_Match & WantRtByM1);

    // Top-level forwarding control signals
    assign D1_RsFwdSel = (D1_Fwd_1) ? 1'b1  : 1'b0;
    assign D1_RtFwdSel = (D1_Fwd_2) ? 1'b1  : 1'b0;
    assign D2_RsFwdSel = ((D2_Fwd_1) ? 2'b01 : ((D2_Fwd_3) ? 2'b10 : ((D2_Fwd_5) ? 2'b11 : 2'b00))) | {2{D2_Fwd_7}};
    assign D2_RtFwdSel = (D2_Fwd_2) ? 2'b01 : ((D2_Fwd_4) ? 2'b10 : ((D2_Fwd_6) ? 2'b11 : 2'b00));
    assign X1_RsFwdSel = (X1_Fwd_1) ? 2'b01 : ((X1_Fwd_3) ? 2'b10 : ((X1_Fwd_5) ? 2'b11 : 2'b00));
    assign X1_RtFwdSel = (X1_Fwd_2) ? 2'b01 : ((X1_Fwd_4) ? 2'b10 : ((X1_Fwd_6) ? 2'b11 : 2'b00));
    assign M1_RtFwdSel = (M1_Fwd_2) ? 2'b01 : ((M1_Fwd_4) ? 2'b10 : 2'b00);

    // GPR data hazard stalls
    wire D2_Data_Stall = |{D2_Stall_1, D2_Stall_2, D2_Stall_3, D2_Stall_4, D2_Stall_5, D2_Stall_6};
    wire X1_Data_Stall = |{X1_Stall_1, X1_Stall_2, X1_Stall_3, X1_Stall_4};
    wire M1_Data_Stall = |{M1_Stall_1};

    // ALU Long operation stalls
    wire X1_ALU_Stall = X1_HiLoRead & |{(M1_HiLoWrite & M1_X1Issued), (M2_HiLoWrite & M2_M1Issued), (W1_HiLoWrite & W1_M2Issued)};
    wire W1_ALU_Stall = W1_HiLoWrite & (ALU_MulBusy | ALU_DivBusy);

    // Reverse branch stalls: D2 sets the new PC but must wait if F1 is stalled (e.g., F2 cache miss)
    // Unnecessary stalls are prevented if the instruction was not issued in D2 to begin with.
    // (In-D2 stalls/flushes will have stalled the pipeline anyway, and jmp/branch don't directly cause exceptions.)
    // However, it still stalls if a branch is not taken to preserve the RestartPC logic of the next instruction.
    // This delay could be removed by additional logic in the future.
    wire D2_Branch_Stall = D2_NextIsBDS & D2_D1Issued & F2_Cache_Stall;
    wire D2_NonBranch_Stall;

    // Cascade stalls: pipeline stage stalls block all previous stages
    wire W1_ICache_Stall  = (W1_ExcDetected | (W1_XOP & W1_M2Issued)) & F2_Cache_Blocked;
    wire F1_Cascade_Stall = |{W1_Stall, M2_Stall, M1_Stall, X1_Stall, D2_NonBranch_Stall, D1_Stall, F2_Stall};
    wire F2_Cascade_Stall = |{W1_Stall, M2_Stall, M1_Stall, X1_Stall, D2_NonBranch_Stall, D1_Stall};
    wire D1_Cascade_Stall = |{W1_Stall, M2_Stall, M1_Stall, X1_Stall, D2_Stall};
    wire D2_Cascade_Stall = |{W1_Stall, M2_Stall, M1_Stall, X1_Stall};
    wire X1_Cascade_Stall = |{W1_Stall, M2_Stall, M1_Stall};
    wire M1_Cascade_Stall = |{W1_Stall, M2_Stall};
    wire M2_NonMem_Cascade_Stall = |{W1_NonMem_Stall, W1_ICache_Stall};
    wire M2_Cascade_Stall = |{W1_Stall};

    // Top-level stall signals
    assign F1_Stall           = |{F1_Cascade_Stall};
    assign F2_NonMem_Stall    = |{F2_Cascade_Stall};
    assign F2_Stall           = |{F2_Cascade_Stall, F2_Cache_Stall};
    assign D1_Stall           = |{D1_Cascade_Stall};
    assign D2_NonBranch_Stall = |{D2_Cascade_Stall, D2_Data_Stall};
    assign D2_Stall           = |{D2_Cascade_Stall, D2_Data_Stall, D2_Branch_Stall};
    assign X1_Stall           = |{X1_Cascade_Stall, X1_Data_Stall, X1_ALU_Stall};
    assign M1_Stall           = |{M1_Cascade_Stall, M1_Data_Stall};
    assign M2_NonMem_Stall    = |{M2_NonMem_Cascade_Stall};
    assign M2_Stall           = |{M2_Cascade_Stall, M2_Cache_Stall};
    assign W1_NonMem_Stall    = W1_ALU_Stall;
    assign W1_Stall           = |{W1_NonMem_Stall, W1_ICache_Stall};

    // TODO XXX: Verify that W1 can stall without screwing up TLB/memory accesses and cancelations.

    // Local and top-level flush signals
    assign W1_Flush_Pending = W1_ExcDetected | (W1_XOP & W1_M2Issued);
    assign W1_Flush = W1_Flush_Pending & ~F2_Cache_Blocked & ~W1_NonMem_Stall;
    assign M2_Flush = W1_Flush;
    assign M1_Flush = W1_Flush;
    assign X1_Flush = W1_Flush;
    assign D2_Flush = W1_Flush;
    assign D1_Flush = W1_Flush;
    assign F2_Flush = W1_Flush | (D2_Branch & D1_F2Issued);
    assign F1_Flush = W1_Flush | D2_Branch;

endmodule

