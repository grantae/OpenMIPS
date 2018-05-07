`timescale 1ns / 1ps
/*
 * File         : MIPS32.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   28-Oct-2014  GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The top-level MIPS32 Release 1 processor core with integrated L1
 *   instruction and data caches.
 *
 *   Each cache has its own memory port. The instruction cache is read-only
 *   while the data cache is read/write. The data cache accesses 16-byte
 *   cachelines as well as 32-bit words (for uncacheable memory regions).
 *
 *   The parameter 'PABITS' specifies the size of physical memory (12 < PABITS < 37).
 *   For example, For 64 MB of RAM, PABITS=26.
 */
module MIPS32 #(parameter PABITS=32) (
    input                 clock,
    input                 reset,
    input                 Core_Reset,              // Processor-local reset
    output [(PABITS-3):0] InstMem_Address,         // Instruction word address
    output                InstMem_ReadLine,        // Instruction memory read command: Reads the cacheline of the word address
    output                InstMem_ReadWord,        // Instruction memory read command: Reads a word from an uncacheable word address
    input                 InstMem_Ready,           // Instruction memory ready (1-cycle)
    input  [31:0]         InstMem_In,              // One instruction from memory
    input  [1:0]          InstMem_Offset,          // Instruction offset within the cacheline (lower 2 bits of the word address)
    output [(PABITS-3):0] DataMem_Address,         // Data word address
    output                DataMem_ReadLine,        // Data cacheline read command
    output                DataMem_ReadWord,        // Data word read command
    input  [31:0]         DataMem_In,              // One data word from memory
    input                 DataMem_Ready,           // Data memory ready for reads/writes (1-cycle)
    input  [1:0]          DataMem_Offset,          // Data offset within the cacheline (lower 2 bits of the word address)
    output                DataMem_WriteLineReady,  // Data write cacheline command
    output                DataMem_WriteWordReady,  // Data write word command
    output [3:0]          DataMem_WriteWordBE,     // Byte enable signals for a data write word command
    output [127:0]        DataMem_Out,             // Data to memory ([127:0] for cacheline, [31:0] for word access)
    input  [4:0]          Interrupts,              // MIPS32 hardware interrupts
    input                 NMI                      // MIPS32 non-maskable interrupt
    );

    // Instruction cache signals
    wire [9:0]           ICache_VAddressIn_C;
    wire [(PABITS-13):0] ICache_PAddressIn_C;
    wire                 ICache_PAddressValid_C;
    wire [2:0]           ICache_CacheAttr_C;
    wire                 ICache_Stall_C;
    wire                 ICache_Read_C;
    wire [31:0]          ICache_DataOut_C;
    wire                 ICache_Ready_C;
    wire                 ICache_Blocked_C;
    wire                 ICache_DoCacheOp_C;
    wire [2:0]           ICache_CacheOp_C;
    wire [(PABITS-11):0] ICache_CacheOpData_C;
    wire [(PABITS-3):0]  ICache_Address_M;
    wire                 ICache_ReadLine_M;
    wire                 ICache_ReadWord_M;
    wire [31:0]          ICache_DataIn_M;
    wire [1:0]           ICache_DataInOffset_M;
    wire                 ICache_Ready_M;

    // Data cache signals
    wire [9:0]           DCache_VAddressIn_C;
    wire [(PABITS-13):0] DCache_PAddressIn_C;
    wire                 DCache_PAddressValid_C;
    wire [2:0]           DCache_CacheAttr_C;
    wire                 DCache_Stall_C;
    wire [31:0]          DCache_DataIn_C;
    wire                 DCache_Read_C;
    wire [3:0]           DCache_Write_C;
    wire [31:0]          DCache_DataOut_C;
    wire                 DCache_Ready_C;
    wire                 DCache_DoCacheOp_C;
    wire [2:0]           DCache_CacheOp_C;
    wire [(PABITS-9):0]  DCache_CacheOpData_C;
    wire [(PABITS-3):0]  DCache_Address_M;
    wire                 DCache_ReadLine_M;
    wire                 DCache_ReadWord_M;
    wire [31:0]          DCache_DataIn_M;
    wire [1:0]           DCache_DataInOffset_M;
    wire                 DCache_LineOutReady_M;
    wire                 DCache_WordOutReady_M;
    wire [3:0]           DCache_WordOutBE_M;
    wire [127:0]         DCache_DataOut_M;
    wire                 DCache_Ready_M;

    // Processor core signals
    wire [9:0]           Core_InstMem_VAddress;
    wire [(PABITS-13):0] Core_InstMem_PAddress;
    wire                 Core_InstMem_PAddressValid;
    wire [2:0]           Core_InstMem_CacheAttr;
    wire                 Core_InstMem_Read;
    wire                 Core_InstMem_Stall;
    wire                 Core_InstMem_DoCacheOp;
    wire [2:0]           Core_InstMem_CacheOp;
    wire [(PABITS-11):0] Core_InstMem_CacheOpData;
    wire [31:0]          Core_InstMem_In;
    wire                 Core_InstMem_Ready;
    wire                 Core_InstMem_Blocked;
    wire [9:0]           Core_DataMem_VAddress;
    wire [(PABITS-13):0] Core_DataMem_PAddress;
    wire                 Core_DataMem_PAddressValid;
    wire [2:0]           Core_DataMem_CacheAttr;
    wire                 Core_DataMem_Read;
    wire [3:0]           Core_DataMem_Write;
    wire [31:0]          Core_DataMem_Out;
    wire                 Core_DataMem_Stall;
    wire                 Core_DataMem_DoCacheOp;
    wire [2:0]           Core_DataMem_CacheOp;
    wire [(PABITS-9):0]  Core_DataMem_CacheOpData;
    wire [31:0]          Core_DataMem_In;
    wire                 Core_DataMem_Ready;
    wire [4:0]           Core_Interrupts;
    wire                 Core_NMI;

    // Top-level assignments
    assign InstMem_Address        = ICache_Address_M;
    assign InstMem_ReadLine       = ICache_ReadLine_M;
    assign InstMem_ReadWord       = ICache_ReadWord_M;
    assign DataMem_Address        = DCache_Address_M;
    assign DataMem_ReadLine       = DCache_ReadLine_M;
    assign DataMem_ReadWord       = DCache_ReadWord_M;
    assign DataMem_WriteLineReady = DCache_LineOutReady_M;
    assign DataMem_WriteWordReady = DCache_WordOutReady_M;
    assign DataMem_WriteWordBE    = DCache_WordOutBE_M;
    assign DataMem_Out            = DCache_DataOut_M;

    // Instruction cache assignments
    assign ICache_VAddressIn_C    = Core_InstMem_VAddress;
    assign ICache_PAddressIn_C    = Core_InstMem_PAddress;
    assign ICache_PAddressValid_C = Core_InstMem_PAddressValid;
    assign ICache_CacheAttr_C     = Core_InstMem_CacheAttr;
    assign ICache_Stall_C         = Core_InstMem_Stall;
    assign ICache_Read_C          = Core_InstMem_Read;
    assign ICache_DoCacheOp_C     = Core_InstMem_DoCacheOp;
    assign ICache_CacheOp_C       = Core_InstMem_CacheOp;
    assign ICache_CacheOpData_C   = Core_InstMem_CacheOpData;
    assign ICache_DataIn_M        = InstMem_In;
    assign ICache_DataInOffset_M  = InstMem_Offset;
    assign ICache_Ready_M         = InstMem_Ready;

    // Data cache assignments
    assign DCache_VAddressIn_C    = Core_DataMem_VAddress;
    assign DCache_PAddressIn_C    = Core_DataMem_PAddress;
    assign DCache_PAddressValid_C = Core_DataMem_PAddressValid;
    assign DCache_CacheAttr_C     = Core_DataMem_CacheAttr;
    assign DCache_Stall_C         = Core_DataMem_Stall;
    assign DCache_DataIn_C        = Core_DataMem_Out;
    assign DCache_Read_C          = Core_DataMem_Read;
    assign DCache_Write_C         = Core_DataMem_Write;
    assign DCache_DoCacheOp_C     = Core_DataMem_DoCacheOp;
    assign DCache_CacheOp_C       = Core_DataMem_CacheOp;
    assign DCache_CacheOpData_C   = Core_DataMem_CacheOpData;
    assign DCache_DataIn_M        = DataMem_In;
    assign DCache_DataInOffset_M  = DataMem_Offset;
    assign DCache_Ready_M         = DataMem_Ready;

    // Core assignments
    assign Core_InstMem_In          = ICache_DataOut_C;
    assign Core_InstMem_Ready       = ICache_Ready_C;
    assign Core_InstMem_Blocked     = ICache_Blocked_C;
    assign Core_DataMem_In          = DCache_DataOut_C;
    assign Core_DataMem_Ready       = DCache_Ready_C;
    assign Core_Interrupts          = Interrupts;
    assign Core_NMI                 = NMI;

    // Instruction Memory Cache
    InstructionCache_8KB #(
        .PABITS          (PABITS))
        ICache (
        .clock           (clock),
        .reset           (reset),
        .VAddressIn_C    (ICache_VAddressIn_C),     // input [9 : 0] VAddressIn_C
        .PAddressIn_C    (ICache_PAddressIn_C),     // input [23 : 0] PAddressIn_C
        .PAddressValid_C (ICache_PAddressValid_C),  // input PAddressValid_C
        .CacheAttr_C     (ICache_CacheAttr_C),      // input [2 : 0] CacheAttr_C
        .Stall_C         (ICache_Stall_C),          // input Stall_C
        .Read_C          (ICache_Read_C),           // input Read_C
        .DataOut_C       (ICache_DataOut_C),        // output [31 : 0] DataOut_C
        .Ready_C         (ICache_Ready_C),          // output Ready_C
        .Blocked_C       (ICache_Blocked_C),        // output Blocked_C
        .DoCacheOp_C     (ICache_DoCacheOp_C),      // input DoCacheOp_C
        .CacheOp_C       (ICache_CacheOp_C),        // input [2:0] CacheOp_C
        .CacheOpData_C   (ICache_CacheOpData_C),    // input [? : 0] CacheOpData_C
        .Address_M       (ICache_Address_M),        // output [? : 0] Address_M
        .ReadLine_M      (ICache_ReadLine_M),       // output ReadLine_M
        .ReadWord_M      (ICache_ReadWord_M),       // output ReadWord_M
        .DataIn_M        (ICache_DataIn_M),         // input [31 : 0] DataIn_M
        .DataInOffset_M  (ICache_DataInOffset_M),   // input [1 : 0] DataInOffset_M
        .Ready_M         (ICache_Ready_M)           // input Ready_M
    );

    // Data Memory Cache
    DataCache_2KB #(
        .PABITS          (PABITS))
        DCache (
        .clock           (clock),
        .reset           (reset),
        .VAddressIn_C    (DCache_VAddressIn_C),     // input [9 : 0] VAddressIn_C
        .PAddressIn_C    (DCache_PAddressIn_C),     // input [23 : 0] PAddressIn_C
        .PAddressValid_C (DCache_PAddressValid_C),  // input PAddressValid_C
        .CacheAttr_C     (DCache_CacheAttr_C),      // input [2 : 0] CacheAttr_C
        .Stall_C         (DCache_Stall_C),          // input Stall_C
        .DataIn_C        (DCache_DataIn_C),         // input [31 : 0] DataIn_C
        .Read_C          (DCache_Read_C),           // input Read_C
        .Write_C         (DCache_Write_C),          // input [3 : 0] Write_C
        .DataOut_C       (DCache_DataOut_C),        // output [31 : 0] DataOut_C
        .Ready_C         (DCache_Ready_C),          // output Ready_C
        .DoCacheOp_C     (DCache_DoCacheOp_C),      // input DoCacheOp_C
        .CacheOp_C       (DCache_CacheOp_C),        // input [2 : 0] CacheOp_C
        .CacheOpData_C   (DCache_CacheOpData_C),    // input [? : 0] CacheOpData_C
        .Address_M       (DCache_Address_M),        // output [? : 0] Address_M
        .ReadLine_M      (DCache_ReadLine_M),       // output ReadLine_M
        .ReadWord_M      (DCache_ReadWord_M),       // output ReadWord_M
        .DataIn_M        (DCache_DataIn_M),         // input [31 : 0] DataIn_M
        .DataInOffset_M  (DCache_DataInOffset_M),   // input [1 : 0] DataInOffset_M
        .LineOutReady_M  (DCache_LineOutReady_M),   // output LineOutReady_M
        .WordOutReady_M  (DCache_WordOutReady_M),   // output WordOutReady_M
        .WordOutBE_M     (DCache_WordOutBE_M),      // output [3 : 0] WordOutBE_M
        .DataOut_M       (DCache_DataOut_M),        // output [127 : 0] DataOut_M
        .Ready_M         (DCache_Ready_M)           // input Ready_M
    );

    // MIPS32r1 Core
    Processor #(
        .PABITS               (PABITS))
        Core (
        .clock                (clock),                       // input clock
        .reset                (Core_Reset),                  // input reset
        .InstMem_VAddress     (Core_InstMem_VAddress),       // output [9 : 0] InstMem_VAddress
        .InstMem_PAddress     (Core_InstMem_PAddress),       // output [23 : 0] InstMem_PAddress
        .InstMem_PAddressValid (Core_InstMem_PAddressValid), // output InstMem_PAddressValid
        .InstMem_CacheAttr    (Core_InstMem_CacheAttr),      // output [2 : 0] InstMem_CacheAttr
        .InstMem_Read         (Core_InstMem_Read),           // output InstMem_Read
        .InstMem_Stall        (Core_InstMem_Stall),          // output InstMem_Stall
        .InstMem_DoCacheOp    (Core_InstMem_DoCacheOp),      // output InstMem_DoCacheOp
        .InstMem_CacheOp      (Core_InstMem_CacheOp),        // output [2 : 0] InstMem_CacheOp
        .InstMem_CacheOpData  (Core_InstMem_CacheOpData),    // output [? : 0] InstMem_CacheOpData
        .InstMem_In           (Core_InstMem_In),             // input [31 : 0] InstMem_In
        .InstMem_Ready        (Core_InstMem_Ready),          // input InstMem_Ready
        .InstMem_Blocked      (Core_InstMem_Blocked),        // input InstMem_Blocked
        .DataMem_VAddress     (Core_DataMem_VAddress),       // output [9 : 0] DataMem_VAddress
        .DataMem_PAddress     (Core_DataMem_PAddress),       // output [23 : 0] DataMem_PAddress
        .DataMem_PAddressValid (Core_DataMem_PAddressValid), // output DataMem_PAddressValid
        .DataMem_CacheAttr    (Core_DataMem_CacheAttr),      // output [2 : 0] DataMem_CacheAttr
        .DataMem_Read         (Core_DataMem_Read),           // output DataMem_Read
        .DataMem_Write        (Core_DataMem_Write),          // output [3 : 0] DataMem_Write
        .DataMem_Out          (Core_DataMem_Out),            // output [31 : 0] DataMem_Out
        .DataMem_Stall        (Core_DataMem_Stall),          // output DataMem_Stall
        .DataMem_DoCacheOp    (Core_DataMem_DoCacheOp),      // output DataMem_DoCacheOp
        .DataMem_CacheOp      (Core_DataMem_CacheOp),        // output [2 : 0] DataMem_CacheOp
        .DataMem_CacheOpData  (Core_DataMem_CacheOpData),    // output [? : 0] DataMem_CacheOpData
        .DataMem_In           (Core_DataMem_In),             // input [31 : 0] DataMem_In
        .DataMem_Ready        (Core_DataMem_Ready),          // input DataMem_Ready
        .Interrupts           (Core_Interrupts),             // input [4 : 0] Interrupts
        .NMI                  (Core_NMI)                     // input NMI
    );

endmodule

