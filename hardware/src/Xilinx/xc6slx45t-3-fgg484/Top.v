`timescale 1ns / 1ps
/*
 * File         : Top.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.utah.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   1-Sep-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   The top-level file for the FPGA. Also known as the 'motherboard,' this
 *   file connects all processor, memory, clocks, and I/O devices together.
 *   All inputs and outputs correspond to actual FPGA pins.
 */
module Top(
    input  clock_50MHz,
    input  reset_p,
    // I/O
    input  [7:0] Switch,
    output [14:0] LED,
    input  UART_Rx,
    output UART_Tx
    );

    localparam PABITS = 32;     // 12 < PABITS <= 36. (e.g., 26 bits -> 64 MB physical RAM). EXPERIMENTAL

    // Clock & Reset Signals
    wire clock;
    reg  reset;
    wire ClockGen_ClockIn;
    wire ClockGen_ClockOut;
    wire ClockGen_ResetIn;
    wire ClockGen_Valid;

    // Main Memory Signals
    wire [13:0]  MainMem_I_Address;
    wire [127:0] MainMem_I_DataIn;
    wire [31:0]  MainMem_I_DataOut;
    wire         MainMem_I_Ready;
    wire [1:0]   MainMem_I_DataOutOffset;
    wire         MainMem_I_BootWrite;
    wire         MainMem_I_ReadLine;
    wire         MainMem_I_ReadWord;
    wire [13:0]  MainMem_D_Address;
    wire [127:0] MainMem_D_DataIn;
    wire         MainMem_D_LineInReady;
    wire         MainMem_D_WordInReady;
    wire [3:0]   MainMem_D_WordInBE;
    wire [31:0]  MainMem_D_DataOut;
    wire [1:0]   MainMem_D_DataOutOffset;
    wire         MainMem_D_ReadLine;
    wire         MainMem_D_ReadWord;
    wire         MainMem_D_Ready;

    // MIPS32 Processor and Cache Signals
    wire         MIPS32_Core_Reset;
    wire [(PABITS-3):0]  MIPS32_InstMem_Address;
    wire         MIPS32_InstMem_ReadLine;
    wire         MIPS32_InstMem_ReadWord;
    wire         MIPS32_InstMem_Ready;
    wire [31:0]  MIPS32_InstMem_In;
    wire [1:0]   MIPS32_InstMem_Offset;
    wire [(PABITS-3):0]  MIPS32_DataMem_Address;
    wire         MIPS32_DataMem_ReadLine;
    wire         MIPS32_DataMem_ReadWord;
    reg  [31:0]  MIPS32_DataMem_In;
    reg          MIPS32_DataMem_Ready;
    wire [1:0]   MIPS32_DataMem_Offset;
    wire         MIPS32_DataMem_WriteLineReady;
    wire         MIPS32_DataMem_WriteWordReady;
    wire [3:0]   MIPS32_DataMem_WriteWordBE;
    wire [127:0] MIPS32_DataMem_Out;
    wire [4:0]   MIPS32_Interrupts;
    wire         MIPS32_NMI;

    // UART Bootloader Signals
    wire         UART_Read;
    wire         UART_Write;
    wire [8:0]   UART_DataIn;
    wire [16:0]  UART_DataOut;
    wire         UART_Ready;
    wire         UART_Interrupt;
    wire         UART_BootResetCPU;
    wire         UART_BootWriteMem;
    wire [17:0]  UART_BootAddress;
    wire [127:0] UART_BootData;
    wire         UART_RxD_Pin;
    wire         UART_TxD_Pin;

    // LED Signals
    wire [13:0] LED_DataIn;
    wire        LED_Write;
    wire        LED_Read;
    wire [13:0] LED_DataOut;
    wire        LED_Ready;
    wire [13:0] LED_Pins;

    // Switch Signals
    wire        Switch_Read;
    wire        Switch_Write;
    wire [7:0]  Switch_Pins;
    wire        Switch_Ready;
    wire [7:0]  Switch_DataOut;

    // Local Signals
    wire MMIO_Word_Write;   // Some MMIO devices only understand 32-bit writes and not byte/half word accesses.


    // **** ASSIGNMENTS **** //

    // Top-level
    assign LED     = {1'b0, LED_Pins};
    assign UART_Tx = UART_TxD_Pin;

    // Local
    assign MMIO_Word_Write = MIPS32_DataMem_WriteWordReady & (MIPS32_DataMem_WriteWordBE == 4'b1111);   // Must use with address to determine a true write condition

    // Clocking and Reset
    assign clock            = ClockGen_ClockOut;
    assign ClockGen_ClockIn = clock_50MHz;
    assign ClockGen_ResetIn = reset_p;

    always @(posedge clock) begin
        reset <= reset_p | ~ClockGen_Valid;
    end


    // Main Memory
    assign MainMem_I_Address      = (UART_BootResetCPU) ? {UART_BootAddress[11:0], 2'b00} : MIPS32_InstMem_Address[13:0];
    assign MainMem_I_DataIn       = UART_BootData;
    assign MainMem_I_BootWrite    = UART_BootWriteMem;   // The bootloader does write to the I$
    assign MainMem_I_ReadLine     = MIPS32_InstMem_ReadLine;
    assign MainMem_I_ReadWord     = MIPS32_InstMem_ReadWord;
    assign MainMem_D_Address      = MIPS32_DataMem_Address[13:0];
    assign MainMem_D_DataIn       = MIPS32_DataMem_Out;
    assign MainMem_D_LineInReady  = MIPS32_DataMem_WriteLineReady;
    assign MainMem_D_WordInReady  = (MIPS32_DataMem_Address[29:26] == 4'b1011) ? 1'b0 : MIPS32_DataMem_WriteWordReady;
    assign MainMem_D_WordInBE     = MIPS32_DataMem_WriteWordBE;
    assign MainMem_D_ReadLine     = MIPS32_DataMem_ReadLine;
    assign MainMem_D_ReadWord     = (MIPS32_DataMem_Address[29:26] == 4'b1011) ? 1'b0 : MIPS32_DataMem_ReadWord;

    // MIPS32 Processor and Caches
    assign MIPS32_Core_Reset     = reset | UART_BootResetCPU;
    assign MIPS32_InstMem_Ready  = MainMem_I_Ready;
    assign MIPS32_InstMem_In     = MainMem_I_DataOut;
    assign MIPS32_InstMem_Offset = MainMem_I_DataOutOffset;
    assign MIPS32_DataMem_Offset = MainMem_D_DataOutOffset;
    assign MIPS32_Interrupts     = {Switch_DataOut[7:5], 1'b0, UART_Interrupt};
    assign MIPS32_NMI            = Switch_DataOut[3];

    always @(*) begin
        case (MIPS32_DataMem_Address[29:26])
            4'b1011:
                begin
                    // Memory-mapped I/O
                    case (MIPS32_DataMem_Address[25:23])
                        3'b011:
                            begin
                                // UART
                                MIPS32_DataMem_In    <= {{15{1'b0}}, UART_DataOut};
                                MIPS32_DataMem_Ready <= UART_Ready;
                            end
                        3'b100:
                            begin
                                // LED
                                MIPS32_DataMem_In    <= {{18{1'b0}}, LED_DataOut};
                                MIPS32_DataMem_Ready <= LED_Ready;
                            end
                        3'b101:
                            begin
                                // Switches
                                MIPS32_DataMem_In    <= {{24{1'b0}}, Switch_DataOut};
                                MIPS32_DataMem_Ready <= Switch_Ready;
                            end
                        default:
                            begin
                                // Invalid device
                                MIPS32_DataMem_In    <= {32{1'bx}};
                                MIPS32_DataMem_Ready <= 1'b0;
                            end
                    endcase
                end
            default:
                begin
                    // Main memory
                    MIPS32_DataMem_In    <= MainMem_D_DataOut;
                    MIPS32_DataMem_Ready <= MainMem_D_Ready;
                end
        endcase
    end

    // UART
    assign UART_Read    = (MIPS32_DataMem_Address[29:23] == 7'b1011011) ? MIPS32_DataMem_ReadWord : 1'b0;
    assign UART_Write   = (MIPS32_DataMem_Address[29:23] == 7'b1011011) ? MMIO_Word_Write : 1'b0;
    assign UART_DataIn  = MIPS32_DataMem_Out[8:0];
    assign UART_RxD_Pin = UART_Rx;

    // LEDs
    assign LED_Read     = (MIPS32_DataMem_Address[29:23] == 7'b1011100) ? MIPS32_DataMem_ReadWord : 1'b0;
    assign LED_Write    = (MIPS32_DataMem_Address[29:23] == 7'b1011100) ? MMIO_Word_Write : 1'b0;
    assign LED_DataIn   = MIPS32_DataMem_Out[13:0];

    // Switches
    assign Switch_Read  = (MIPS32_DataMem_Address[29:23] == 7'b1011101) ? MIPS32_DataMem_ReadWord : 1'b0;
    assign Switch_Write = (MIPS32_DataMem_Address[29:23] == 7'b1011101) ? MMIO_Word_Write : 1'b0;
    assign Switch_Pins  = Switch;

    // **** MODULE INSTANTIATION **** //

    // Clock Generation
    Clock_50MHz_to_62p5MHz Clock_Generator (
        .CLK_IN1    (ClockGen_ClockIn),  // input CLK_IN1
        .CLK_OUT1   (ClockGen_ClockOut), // output CLK_OUT1
        .RESET      (ClockGen_ResetIn),  // input RESET
        .CLK_VALID  (ClockGen_Valid)     // output CLK_VALID
    );

    // Main Memory (On-Chip Block RAM)
    MainMemory MainMemory (
        .clock            (clock),                      // input clock
        .reset            (reset),                      // input reset
        .I_Address        (MainMem_I_Address),          // input [13 : 0] I_Address
        .I_DataIn         (MainMem_I_DataIn),           // input [127 : 0] I_DataIn
        .I_DataOut        (MainMem_I_DataOut),          // output [31 : 0] I_DataOut
        .I_Ready          (MainMem_I_Ready),            // output I_Ready
        .I_DataOutOffset  (MainMem_I_DataOutOffset),    // output [1 : 0] I_DataOutOffset
        .I_BootWrite      (MainMem_I_BootWrite),        // input I_BootWrite
        .I_ReadLine       (MainMem_I_ReadLine),         // input I_ReadLine
        .I_ReadWord       (MainMem_I_ReadWord),         // input I_ReadWord
        .D_Address        (MainMem_D_Address),          // input [13 : 0] D_Address
        .D_DataIn         (MainMem_D_DataIn),           // input [127 : 0] D_DataIn
        .D_LineInReady    (MainMem_D_LineInReady),      // input D_LineInReady
        .D_WordInReady    (MainMem_D_WordInReady),      // input D_WordInReady
        .D_WordInBE       (MainMem_D_WordInBE),         // input [3 : 0] D_WordInBE
        .D_DataOut        (MainMem_D_DataOut),          // output [31 : 0] D_DataOut
        .D_DataOutOffset  (MainMem_D_DataOutOffset),    // output [1 : 0] D_DataOutOffset
        .D_ReadLine       (MainMem_D_ReadLine),         // input D_ReadLine
        .D_ReadWord       (MainMem_D_ReadWord),         // input D_ReadWord
        .D_Ready          (MainMem_D_Ready)             // output D_Ready
    );

    // MIPS32 Processor and Caches
    MIPS32 #(
        .PABITS                  (PABITS))
        MIPS32 (
        .clock                   (clock),                           // input clock
        .reset                   (reset),                           // input reset
        .Core_Reset              (MIPS32_Core_Reset),               // input Core_Reset
        .InstMem_Address         (MIPS32_InstMem_Address),          // output [? : 0] InstMem_Address
        .InstMem_ReadLine        (MIPS32_InstMem_ReadLine),         // output InstMem_ReadLine
        .InstMem_ReadWord        (MIPS32_InstMem_ReadWord),         // output InstMem_ReadWord
        .InstMem_Ready           (MIPS32_InstMem_Ready),            // input InstMem_Ready
        .InstMem_In              (MIPS32_InstMem_In),               // input [31 : 0] InstMem_In
        .InstMem_Offset          (MIPS32_InstMem_Offset),           // input [1 : 0] InstMem_Offset
        .DataMem_Address         (MIPS32_DataMem_Address),          // output [? : 0] DataMem_Address
        .DataMem_ReadLine        (MIPS32_DataMem_ReadLine),         // output DataMem_ReadLine
        .DataMem_ReadWord        (MIPS32_DataMem_ReadWord),         // output DataMem_ReadWord
        .DataMem_In              (MIPS32_DataMem_In),               // input [31 : 0] DataMem_In
        .DataMem_Ready           (MIPS32_DataMem_Ready),            // input DataMem_Ready
        .DataMem_Offset          (MIPS32_DataMem_Offset),           // input [1 : 0] DataMem_Offset
        .DataMem_WriteLineReady  (MIPS32_DataMem_WriteLineReady),   // output DataMem_WriteLineReady
        .DataMem_WriteWordReady  (MIPS32_DataMem_WriteWordReady),   // output DataMem_WriteWordReady
        .DataMem_WriteWordBE     (MIPS32_DataMem_WriteWordBE),      // output [3 : 0] DataMem_WriteWord_BE
        .DataMem_Out             (MIPS32_DataMem_Out),              // output [127 : 0] DataMem_Out
        .Interrupts              (MIPS32_Interrupts),               // input [4 : 0] Interrupts
        .NMI                     (MIPS32_NMI)                       // input NMI
    );

    // UART + Boot Loader (v2)
    uart_bootloader_128 UART (
        .clock         (clock),             // input clock
        .reset         (reset),             // input reset
        .Read          (UART_Read),         // input Read
        .Write         (UART_Write),        // input Write
        .DataIn        (UART_DataIn),       // input [8 : 0] DataIn
        .DataOut       (UART_DataOut),      // output [16 : 0] DataOut
        .Ready         (UART_Ready),        // output Ready
        .DataReady     (UART_Interrupt),    // output DataReady
        .BootResetCPU  (UART_BootResetCPU), // output BootResetCPU
        .BootWriteMem  (UART_BootWriteMem), // output BootWriteMem
        .BootAddr      (UART_BootAddress),  // output [17 : 0] BootAddr
        .BootData      (UART_BootData),     // output [31 : 0] BootData
        .RxD           (UART_RxD_Pin),      // input RxD
        .TxD           (UART_TxD_Pin)       // output TxD
    );

    // LEDs
    LED LEDs (
        .clock    (clock),          // input clock
        .reset    (reset),          // input reset
        .dataIn   (LED_DataIn),     // input [13 : 0] dataIn
        .Write    (LED_Write),      // input Write
        .Read     (LED_Read),       // input Read
        .dataOut  (LED_DataOut),    // output [13 : 0] dataOut
        .Ready    (LED_Ready),      // output Ready
        .LED      (LED_Pins)        // output LED
    );

    // Filtered Input Switches
    Switches Switches (
        .clock       (clock),           // input clock
        .reset       (reset),           // input reset
        .Read        (Switch_Read),     // input Read
        .Write       (Switch_Write),    // input Write
        .Switch_in   (Switch_Pins),     // input [7 : 0] Switch_in
        .Ready       (Switch_Ready),    // output Ready
        .Switch_out  (Switch_DataOut)   // output [7 : 0] Switch_out
    );

endmodule

