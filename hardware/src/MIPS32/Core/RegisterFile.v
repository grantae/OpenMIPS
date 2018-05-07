`timescale 1ns / 1ps
/*
 * File         : RegisterFile.v
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A Register File for a MIPS processor. Contains 32 general-purpose
 *   32-bit wide registers and two read ports. Register 0 always reads
 *   as zero.
 */
module RegisterFile(
    input  clock,
    input  [4:0]  ReadReg1,
    input  [4:0]  ReadReg2,
    input  [4:0]  WriteReg,
    input  [31:0] WriteData,
    input         WriteEnable,
    output [31:0] ReadData1,
    output [31:0] ReadData2
    );

    // Register file of 32 32-bit registers.
    reg [31:0] registers [0:31];

    // Initialize all to zero
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] <= {32{1'b0}};
        end
    end

    // Register 0 is hardwired to 0s
    wire [31:0] write_data = (WriteReg == 5'd0) ? {32{1'b0}} : WriteData;

    // Synchronous (clocked) writes
    always @(posedge clock) begin
        if (WriteEnable) begin
            registers[WriteReg] <= write_data;
        end
    end

    // Asynchronous (combinatorial) reads
    assign ReadData1 = registers[ReadReg1];
    assign ReadData2 = registers[ReadReg2];

endmodule

