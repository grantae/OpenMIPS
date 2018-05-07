`timescale 1ns / 1ps
/*
 * File         : ReadDataControl.v
 * Project      : XUM MIPS32 cache enhancement
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   3-Oct-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Memory read data manipulator. Transforms read data coming
 *   into the processor for sub-word and unaligned accesses,
 *   atomic conditions, and endianness.
 */
module ReadDataControl(
    input  [1:0]  Address,      // The two least significant bits of the (32-bit) address
    input         Byte,
    input         Half,
    input         SignExtend,
    input         Left,
    input         Right,
    input         BigEndian,
    input         SC,           // A Store Conditional operation
    input         Atomic,       // Atomic condition and value of the Store Conditional operation
    input  [31:0] RegData,      // Unmodified register data from an unaligned load
    input  [31:0] ReadData,     // Read data from memory
    output reg [31:0] DataOut   // Data for the processor
    );

    wire Half_Access_L  = ~Address[1];
    wire Half_Access_R  =  Address[1];
    wire Byte_Access_LL = Half_Access_L & ~Address[0];
    wire Byte_Access_LM = Half_Access_L &  Address[0];
    wire Byte_Access_RM = Half_Access_R & ~Address[0];
//  wire Byte_Access_RR = Half_Access_R &  Address[0];

    always @(*) begin
        if (Byte) begin
            if (Byte_Access_LL) begin
                DataOut[31:8] <= {24{SignExtend & ReadData[31]}};
                DataOut[7:0]  <= ReadData[31:24];
            end
            else if (Byte_Access_LM) begin
                DataOut[31:8] <= {24{SignExtend & ReadData[23]}};
                DataOut[7:0]  <= ReadData[23:16];
            end
            else if (Byte_Access_RM) begin
                DataOut[31:8] <= {24{SignExtend & ReadData[15]}};
                DataOut[7:0]  <= ReadData[15:8];
            end
            else begin
                DataOut[31:8] <= {24{SignExtend & ReadData[7]}};
                DataOut[7:0]  <= ReadData[7:0];
            end
        end
        else if (Half) begin
            if (Half_Access_L) begin
                DataOut[31:16] <= (BigEndian) ? {16{SignExtend & ReadData[31]}} : {16{SignExtend & ReadData[23]}};
                DataOut[15:0]  <= (BigEndian) ? ReadData[31:16] : {ReadData[23:16], ReadData[31:24]};
            end
            else begin
                DataOut[31:16] <= (BigEndian) ? {16{SignExtend & ReadData[15]}} : {16{SignExtend & ReadData[7]}};
                DataOut[15:0]  <= (BigEndian) ? ReadData[15:0] : {ReadData[7:0], ReadData[15:8]};
            end
        end
        else if (SC) begin
            DataOut <= {{31{1'b0}}, Atomic};
        end
        else if (Left) begin
            case (Address[1:0])
                2'b00 : DataOut <= (BigEndian) ?  ReadData                       : {ReadData[31:24], RegData[23:0]};
                2'b01 : DataOut <= (BigEndian) ? {ReadData[23:0], RegData[7:0]}  : {ReadData[23:16], ReadData[31:24], RegData[15:0]};
                2'b10 : DataOut <= (BigEndian) ? {ReadData[15:0], RegData[15:0]} : {ReadData[15:8],  ReadData[23:16], ReadData[31:24],  RegData[7:0]};
                2'b11 : DataOut <= (BigEndian) ? {ReadData[7:0],  RegData[23:0]} : {ReadData[7:0], ReadData[15:8], ReadData[23:16], ReadData[31:24]};
            endcase
        end
        else if (Right) begin
            case (Address[1:0])
                2'b00 : DataOut <= (BigEndian) ? {RegData[31:8],  ReadData[31:24]} : {ReadData[7:0], ReadData[15:8], ReadData[23:16], ReadData[31:24]};
                2'b01 : DataOut <= (BigEndian) ? {RegData[31:16], ReadData[31:16]} : {RegData[31:24], ReadData[7:0], ReadData[15:8], ReadData[23:16]};
                2'b10 : DataOut <= (BigEndian) ? {RegData[31:24], ReadData[31:8]}  : {RegData[31:16], ReadData[7:0], ReadData[15:8]};
                2'b11 : DataOut <= (BigEndian) ?  ReadData                         : {RegData[31:8],  ReadData[7:0]};
            endcase
        end
        else begin
            DataOut <= (BigEndian) ? ReadData : {ReadData[7:0], ReadData[15:8], ReadData[23:16], ReadData[31:24]};
        end
    end

endmodule

