`timescale 1ns / 1ps
/*
 * File         : MemControl.v
 * Project      : MIPS32 MUX
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A Data Memory Controller which handles all read and write requests from the
 *   processor to data memory. All data accesses--whether big endian, little endian,
 *   byte, half, word, or unaligned transfers--are transformed into a simple read
 *   and write command to data memory over a 32-bit data bus, where the read command
 *   is one bit and the write command is 4 bits, one for each byte in the 32-bit word.
 *
 *   Some of the logic, such as cache/TLB hit detection, TLB-based write cancelation,
 *   atomic LLSC detection, and sub-word read processing occurs in the next pipeline
 *   stage (M2) due to the pipelined access behavior of the TLB and caches.
 */
module MemControl(
    input         clock,
    input         reset,
    input         M1_Issued,          // The M1 stage is not stalled or flushed
    input  [31:0] DataIn,             // Write data from CPU
    input  [31:0] Address,            // Data address from CPU
    input         Read,               // Memory Read command from CPU
    input         Write,              // Memory Write command from CPU
    input         Byte,               // Load/Store is Byte (8-bit)
    input         Half,               // Load/Store is Half (16-bit)
    input         Left,               // Unaligned Load/Store Word Left
    input         Right,              // Unaligned Load/Store Word Right
    input         LLSC,               // A load-linked or store-conditional operation
    input         ICacheOp,           // The instruction is 'cache' for the i-cache
    input         DCacheOp,           // The instruction is 'cache' for the d-cache
    input         Eret,               // An issued Eret instruction (clears atomic LLSC bit)
    input         ReverseEndian,      // Reverse Endian Memory for User Mode (includes RE and kernel mode)
    input         KernelMode,         // (Exception logic)
    output [31:0] Mem_WriteData,      // Data to Memory
    output [3:0]  Mem_WriteEnable,    // Write Enable to Memory for each of 4 bytes of Memory
    output        Mem_ReadEnable,     // Read Enable to Memory
    output        Mem_DCacheOpEnable, // D-Cache management operation enable
    output        EXC_AdEL,           // Load Exception
    output        EXC_AdES,           // Store Exception
    output        M_BigEndian,        // Data memory is operating in big-endian mode
    output        M2_Atomic           // The LLSC bit is true for the M2 stage
    );

    `include "MIPS_Defines.v"

    /*** Reverse Endian Mode
         The processor is either big- or little-endian as defined by the 'Big_Endian' definition.
         However, the endianness can be reversed in user mode.
    */
    wire BE = `Big_Endian ^ ReverseEndian;

    // Indicator that the current memory reference must be word-aligned
    wire Word = ~|{Half, Byte, Left, Right};

    // Exception Detection
    wire   Exc_KernelMem     = ~KernelMode & Address[31];
    wire   Exc_Word          = Word & (Address[1] | Address[0]);
    wire   Exc_Half          = Half & Address[0];
    assign EXC_AdEL          = (Exc_KernelMem & (Read | ICacheOp | DCacheOp)) | ((Exc_Word | Exc_Half) & Read);
    assign EXC_AdES          = Write & |{Exc_KernelMem, Exc_Word, Exc_Half};

    // Unaligned and sub-word access calculation
    wire Half_Access_L  = ~Address[1];
    wire Half_Access_R  =  Address[1];
    wire Byte_Access_LL = Half_Access_L & ~Address[0];
    wire Byte_Access_LM = Half_Access_L &  Address[0];
    wire Byte_Access_RM = Half_Access_R & ~Address[0];
    wire Byte_Access_RR = Half_Access_R &  Address[0];

    // DEBUG: Mask all accesses to kseg3 (kernel, mapped: virtual 0xe0000000 - 0xffffffff
    wire kseg3 = (Address >= 32'he0000000);

    // Read command to memory
    assign Mem_ReadEnable = Read & M1_Issued & ~kseg3;

    // Write command to memory
    reg [3:0] we;
    assign Mem_WriteEnable = we & {4{~kseg3}};

    // D-Cache command
    assign Mem_DCacheOpEnable = DCacheOp & M1_Issued;  // Masked on EXC_AdEL

    always @(*) begin
        if (Write & M1_Issued) begin
            if (Byte) begin
                we[3] <= Byte_Access_LL;
                we[2] <= Byte_Access_LM;
                we[1] <= Byte_Access_RM;
                we[0] <= Byte_Access_RR;
            end
            else if (Half) begin
                we[3] <= Half_Access_L;
                we[2] <= Half_Access_L;
                we[1] <= Half_Access_R;
                we[0] <= Half_Access_R;
            end
            else if (Left) begin
                case (Address[1:0])
                    2'b00 : we <= (BE) ? 4'b1111 : 4'b1000;
                    2'b01 : we <= (BE) ? 4'b0111 : 4'b1100;
                    2'b10 : we <= (BE) ? 4'b0011 : 4'b1110;
                    2'b11 : we <= (BE) ? 4'b0001 : 4'b1111;
                endcase
            end
            else if (Right) begin
                case (Address[1:0])
                    2'b00 : we <= (BE) ? 4'b1000 : 4'b1111;
                    2'b01 : we <= (BE) ? 4'b1100 : 4'b0111;
                    2'b10 : we <= (BE) ? 4'b1110 : 4'b0011;
                    2'b11 : we <= (BE) ? 4'b1111 : 4'b0001;
                endcase
            end
            else if (LLSC) begin
                we <= (Atomic) ? 4'b1111 : 4'b0000;
            end
            else begin
                we <= 4'b1111;
            end
        end
        else begin
            we <= 4'b0000;
        end
    end

    // Write data to memory
    reg [31:0] wd;
    assign Mem_WriteData = wd;

    generate
        if (`Big_Endian) begin
            always @(*) begin
                if (Byte) begin
                    wd <= {DataIn[7:0], DataIn[7:0], DataIn[7:0], DataIn[7:0]};
                end
                else if (Half) begin
                    wd <= {DataIn[15:0], DataIn[15:0]};
                end
                else if (Left) begin
                    case (Address[1:0])
                        2'b00 : wd <= DataIn;
                        2'b01 : wd <= {{8{1'bx}}, DataIn[31:8]};
                        2'b10 : wd <= {{16{1'bx}}, DataIn[31:16]};
                        2'b11 : wd <= {{24{1'bx}}, DataIn[31:24]};
                    endcase
                end
                else if (Right) begin
                    case (Address[1:0])
                        2'b00 : wd <= {DataIn[7:0], {24{1'bx}}};
                        2'b01 : wd <= {DataIn[15:0], {16{1'bx}}};
                        2'b10 : wd <= {DataIn[23:0], {8{1'bx}}};
                        2'b11 : wd <= DataIn;
                    endcase
                end
                else begin
                    wd <= DataIn;
                end
            end
        end
        else begin
            always @(*) begin
                if (Byte) begin
                    wd <= {DataIn[7:0], DataIn[7:0], DataIn[7:0], DataIn[7:0]};
                end
                else if (Half) begin
                    wd <= {2{{DataIn[7:0], DataIn[15:8]}}};
                end
                else if (Left) begin
                    case (Address[1:0])
                        2'b00 : wd <= {DataIn[31:24], {24{1'bx}}};
                        2'b01 : wd <= {DataIn[23:16], DataIn[31:24], {16{1'bx}}};
                        2'b10 : wd <= {DataIn[15:8],  DataIn[23:16], DataIn[31:24], {8{1'bx}}};
                        2'b11 : wd <= {DataIn[7:0],   DataIn[15:8],  DataIn[23:16], DataIn[31:24]};
                    endcase
                end
                else if (Right) begin
                    case (Address[1:0])
                        2'b00 : wd <= {DataIn[7:0], DataIn[15:8], DataIn[23:16], DataIn[31:24]};
                        2'b01 : wd <= {{8{1'bx}},  DataIn[7:0], DataIn[15:8], DataIn[23:16]};
                        2'b10 : wd <= {{16{1'bx}}, DataIn[7:0], DataIn[15:8]};
                        2'b11 : wd <= {{24{1'bx}}, DataIn[7:0]};
                    endcase
                end
                else begin
                    wd <= {DataIn[7:0], DataIn[15:8], DataIn[23:16], DataIn[31:24]};
                end
            end
        end
    endgenerate

    // Atomic LL/SC logic
    wire [29:0] AtomicAddr;     // 30 MSB of virtual address
    wire        Atomic;         // The operation is atomic; SC should succeed
    wire        addr_en    = M1_Issued & LLSC & Read;
    wire        atomic_en  = M1_Issued;
    wire        addr_match = (AtomicAddr == Address[31:2]);
    wire        non_atomic = (Read | Write) & ~LLSC & addr_match;
    wire        atomic_din = ~Eret & ((LLSC & Read) | (Atomic & ~non_atomic));

    DFF_E   #(.WIDTH(30)) Addr_r   (.clock(clock),                .enable(addr_en),   .D(Address[31:2]), .Q(AtomicAddr));
    DFF_SRE #(.WIDTH(1))  Atomic_r (.clock(clock), .reset(reset), .enable(atomic_en), .D(atomic_din),    .Q(Atomic));

    assign M2_Atomic = Atomic;

    // Endian mode output
    assign M_BigEndian = BE;

endmodule

