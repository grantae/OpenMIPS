`timescale 1ns / 1ps
/*
 * File         : MainMemory.v
 * Project      : XUM MIPS32 cache enhancement
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   10-Sep-2014  GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Block RAM main memory for the MIPS32r1 processor.
 *
 *   This is a small (e.g. 64KB) memory that can be used in place
 *   of a DRAM controller for modest applications and testing.
 *   One data port is for instruction memory while the other is
 *   for data memory. Each port is accessed as a 16-byte cachelines,
 *   although the data port supports 32-bit word accesses (with byte
 *   write enable signals) as well.
 */
module MainMemory #(parameter ADDR_WIDTH=12, parameter CRIT_WORD_FIRST=0) (
    input  clock,
    input  reset,
    // Instruction memory interface
    input  [(ADDR_WIDTH+1):0] I_Address, // Word address
    input  [127:0]    I_DataIn,
    output reg [31:0] I_DataOut,
    output reg        I_Ready,
    output reg [1:0]  I_DataOutOffset,
    input             I_BootWrite,     // Manual writes from boot loader (uses I_DataIn and I_Address)
    input             I_ReadLine,
    input             I_ReadWord,
    // Data memory interface
    input  [(ADDR_WIDTH+1):0] D_Address, // Word address
    input  [127:0]    D_DataIn,
    input             D_LineInReady,
    input             D_WordInReady,
    input  [3:0]      D_WordInBE,
    output reg [31:0] D_DataOut,
    output reg [1:0]  D_DataOutOffset,
    input             D_ReadLine,
    input             D_ReadWord,
    output reg        D_Ready
    );

    localparam [3:0] IDLE=0, WAIT1=1, WAIT2=2, WAIT3=3, WAIT4=4, RW_1=5, RL_1=6, RL_2=7, RL_3=8, RL_4=9, WW_1=10, WW_2=11, WL_1=12;

    // RAM signals
    wire [(ADDR_WIDTH-1):0] RAM_addra, RAM_addrb;  // Line address (4 words or 16 bytes)
    wire         RAM_wea,   RAM_web;
    wire [127:0] RAM_dina,  RAM_dinb;
    wire [127:0] RAM_douta, RAM_doutb;

    // Local signals
    reg [127:0] d_mask;
    reg [3:0]   state_a, state_b;
    reg I_ReadWord_r, I_ReadLine_r;
    reg D_ReadWord_r, D_ReadLine_r;

    // Assignments
    assign RAM_addra = I_Address[(ADDR_WIDTH+1):2];
    assign RAM_wea   = I_BootWrite;
    assign RAM_dina  = I_DataIn;
    assign RAM_addrb = D_Address[(ADDR_WIDTH+1):2];
    assign RAM_web   = (state_b == WW_2) | (state_b == WL_1);
    assign RAM_dinb  = d_mask;

    // Command retention for A and B ports (currently read commands are pulses)
    always @(posedge clock) begin
        I_ReadWord_r <= (state_a == IDLE) ? I_ReadWord : I_ReadWord_r;
        I_ReadLine_r <= (state_a == IDLE) ? I_ReadLine : I_ReadLine_r;
        D_ReadWord_r <= (state_b == IDLE) ? D_ReadWord : D_ReadWord_r;
        D_ReadLine_r <= (state_b == IDLE) ? D_ReadLine : D_ReadLine_r;
    end

    // Port A state machine
    always @(posedge clock) begin
        if (reset) begin
            state_a <= IDLE;
        end
        else begin
            case (state_a)
                IDLE:   state_a <= (I_ReadWord | I_ReadLine) ? WAIT1 : IDLE;
                WAIT1:  state_a <= WAIT4;   // XXX Bypassing WAIT2 to be faster for waveforms.
                WAIT2:  state_a <= WAIT3;
                WAIT3:  state_a <= WAIT4;
                WAIT4:
                    begin
                        if (I_ReadWord_r) state_a <= RW_1;
                        else if (I_ReadLine_r) state_a <= RL_1;
                        else state_a <= IDLE;
                    end
                RW_1:   state_a <= IDLE;
                RL_1:   state_a <= RL_2;
                RL_2:   state_a <= RL_3;
                RL_3:   state_a <= RL_4;
                RL_4:   state_a <= IDLE;
                default: state_a <= IDLE;
            endcase
        end
    end

    // Port B state machine
    always @(posedge clock) begin
        if (reset) begin
            state_b <= IDLE;
        end
        else begin
            case (state_b)
                IDLE:   state_b <= (D_ReadWord | D_ReadLine | D_WordInReady | D_LineInReady) ? WAIT1 : IDLE;
                WAIT1:  state_b <= WAIT2;
                WAIT2:  state_b <= WAIT3;
                WAIT3:  state_b <= WAIT4;
                WAIT4:
                    begin
                        if (D_ReadWord_r) state_b <= RW_1;
                        else if (D_ReadLine_r) state_b <= RL_1;
                        else if (D_WordInReady) state_b <= WW_1;
                        else if (D_LineInReady) state_b <= WL_1;
                        else state_b <= IDLE;
                    end
                RW_1:   state_b <= IDLE;
                RL_1:   state_b <= RL_2;
                RL_2:   state_b <= RL_3;
                RL_3:   state_b <= RL_4;
                RL_4:   state_b <= IDLE;
                WW_1:   state_b <= WW_2;
                WW_2:   state_b <= IDLE;
                WL_1:   state_b <= IDLE;
                default: state_b <= IDLE;
            endcase
        end
    end

    // Port A offset
    generate
        if (CRIT_WORD_FIRST) begin
            always @(posedge clock) begin
                case (state_a)
                    WAIT4:   I_DataOutOffset <= I_Address[1:0];
                    RL_1:    I_DataOutOffset <= I_DataOutOffset + 1'b1;
                    RL_2:    I_DataOutOffset <= I_DataOutOffset + 1'b1;
                    RL_3:    I_DataOutOffset <= I_DataOutOffset + 1'b1;
                    default: I_DataOutOffset <= 2'b00;
                endcase
            end
        end
        else begin
            always @(posedge clock) begin
                case (state_a)
                    WAIT4:   I_DataOutOffset <= (I_ReadWord_r) ? I_Address[1:0] : 2'b00;
                    RL_1:    I_DataOutOffset <= 2'b01;
                    RL_2:    I_DataOutOffset <= 2'b10;
                    RL_3:    I_DataOutOffset <= 2'b11;
                    default: I_DataOutOffset <= 2'b00;
                endcase
            end
        end
    endgenerate

    // Port B offset
    generate
        if (CRIT_WORD_FIRST) begin
            always @(posedge clock) begin
                case (state_b)
                    WAIT4:   D_DataOutOffset <= D_Address[1:0];
                    RL_1:    D_DataOutOffset <= D_DataOutOffset + 1'b1;
                    RL_2:    D_DataOutOffset <= D_DataOutOffset + 1'b1;
                    RL_3:    D_DataOutOffset <= D_DataOutOffset + 1'b1;
                    default: D_DataOutOffset <= 2'b00;
                endcase
            end
        end
        else begin
            always @(posedge clock) begin
                case (state_b)
                    WAIT4:   D_DataOutOffset <= (D_ReadWord_r) ? D_Address[1:0] : 2'b00;
                    RL_1:    D_DataOutOffset <= 2'b01;
                    RL_2:    D_DataOutOffset <= 2'b10;
                    RL_3:    D_DataOutOffset <= 2'b11;
                    default: D_DataOutOffset <= 2'b00;
                endcase
            end
        end
    endgenerate

    // Port A ready
    always @(*) begin
        case (state_a)
            RW_1:    I_Ready <= 1'b1;
            RL_1:    I_Ready <= 1'b1;
            RL_2:    I_Ready <= 1'b1;
            RL_3:    I_Ready <= 1'b1;
            RL_4:    I_Ready <= 1'b1;
            default: I_Ready <= 1'b0;
        endcase
    end

    // Port B ready
    always @(*) begin
        case (state_b)
            RW_1:    D_Ready <= 1'b1;
            RL_1:    D_Ready <= 1'b1;
            RL_2:    D_Ready <= 1'b1;
            RL_3:    D_Ready <= 1'b1;
            RL_4:    D_Ready <= 1'b1;
            WW_2:    D_Ready <= 1'b1;
            WL_1:    D_Ready <= 1'b1;
            default: D_Ready <= 1'b0;
        endcase
    end

    // Port A data out
    always @(*) begin
        case (I_DataOutOffset)
            2'b00: I_DataOut <= RAM_douta[127:96];
            2'b01: I_DataOut <= RAM_douta[95:64];
            2'b10: I_DataOut <= RAM_douta[63:32];
            2'b11: I_DataOut <= RAM_douta[31:0];
        endcase
    end

    // Port B data out
    always @(*) begin
        case (D_DataOutOffset)
            2'b00: D_DataOut <= RAM_doutb[127:96];
            2'b01: D_DataOut <= RAM_doutb[95:64];
            2'b10: D_DataOut <= RAM_doutb[63:32];
            2'b11: D_DataOut <= RAM_doutb[31:0];
        endcase
    end

    always @(posedge clock) begin
        case (state_b)
            WAIT4:
                begin
                    d_mask <= (D_LineInReady) ? D_DataIn : RAM_doutb;
                end
            WW_1:
                begin
                    d_mask[127:120] <= ((D_Address[1:0] == 2'b00) & D_WordInBE[3]) ? D_DataIn[31:24] : d_mask[127:120];
                    d_mask[119:112] <= ((D_Address[1:0] == 2'b00) & D_WordInBE[2]) ? D_DataIn[23:16] : d_mask[119:112];
                    d_mask[111:104] <= ((D_Address[1:0] == 2'b00) & D_WordInBE[1]) ? D_DataIn[15:8]  : d_mask[111:104];
                    d_mask[103:96]  <= ((D_Address[1:0] == 2'b00) & D_WordInBE[0]) ? D_DataIn[7:0]   : d_mask[103:96];
                    d_mask[95:88]   <= ((D_Address[1:0] == 2'b01) & D_WordInBE[3]) ? D_DataIn[31:24] : d_mask[95:88];
                    d_mask[87:80]   <= ((D_Address[1:0] == 2'b01) & D_WordInBE[2]) ? D_DataIn[23:16] : d_mask[87:80];
                    d_mask[79:72]   <= ((D_Address[1:0] == 2'b01) & D_WordInBE[1]) ? D_DataIn[15:8]  : d_mask[79:72];
                    d_mask[71:64]   <= ((D_Address[1:0] == 2'b01) & D_WordInBE[0]) ? D_DataIn[7:0]   : d_mask[71:64];
                    d_mask[63:56]   <= ((D_Address[1:0] == 2'b10) & D_WordInBE[3]) ? D_DataIn[31:24] : d_mask[63:56];
                    d_mask[55:48]   <= ((D_Address[1:0] == 2'b10) & D_WordInBE[2]) ? D_DataIn[23:16] : d_mask[55:48];
                    d_mask[47:40]   <= ((D_Address[1:0] == 2'b10) & D_WordInBE[1]) ? D_DataIn[15:8]  : d_mask[47:40];
                    d_mask[39:32]   <= ((D_Address[1:0] == 2'b10) & D_WordInBE[0]) ? D_DataIn[7:0]   : d_mask[39:32];
                    d_mask[31:24]   <= ((D_Address[1:0] == 2'b11) & D_WordInBE[3]) ? D_DataIn[31:24] : d_mask[31:24];
                    d_mask[23:16]   <= ((D_Address[1:0] == 2'b11) & D_WordInBE[2]) ? D_DataIn[23:16] : d_mask[23:16];
                    d_mask[15:8]    <= ((D_Address[1:0] == 2'b11) & D_WordInBE[1]) ? D_DataIn[15:8]  : d_mask[15:8];
                    d_mask[7:0]     <= ((D_Address[1:0] == 2'b11) & D_WordInBE[0]) ? D_DataIn[7:0]   : d_mask[7:0];
                end
            WW_2:
                begin
                    d_mask <= d_mask;
                end
            default:
                begin
                    d_mask <= RAM_doutb;
                end
        endcase
    end

    /* BRAM variant
    BRAM_128x4096_TDP RAM (
        .clka   (clock),     // input clka
        .rsta   (reset),     // input rsta
        .wea    (RAM_wea),   // input wea
        .addra  (RAM_addra), // input [11 : 0] addra
        .dina   (RAM_dina),  // input [127 : 0] dina
        .douta  (RAM_douta), // output [127 : 0] douta
        .clkb   (clock),     // input clkb
        .rstb   (reset),     // input rstb
        .web    (RAM_web),   // input web
        .addrb  (RAM_addrb), // input [11 : 0] addrb
        .dinb   (RAM_dinb),  // input [127 : 0] dinb
        .doutb  (RAM_doutb)  // output [127 : 0] doutb
    );
    */

    // Dual-port generic RAM
    RAM_TDP #(
        .DATA_WIDTH (128),
        .ADDR_WIDTH (ADDR_WIDTH))
        MainRAM (
        .clk    (clock),     // input clk
        .rst    (reset),     // input rst
        .addra  (RAM_addra), // input [11 : 0] addra
        .wea    (RAM_wea),   // input wea
        .dina   (RAM_dina),  // input [127 : 0] dina
        .douta  (RAM_douta), // output [127 : 0] douta
        .addrb  (RAM_addrb), // input [11 : 0] addrb
        .web    (RAM_web),   // input web
        .dinb   (RAM_dinb),  // input [127 : 0] dinb
        .doutb  (RAM_doutb)  // output [127 : 0] doutb
    );

endmodule

