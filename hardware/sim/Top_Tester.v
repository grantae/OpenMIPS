`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   12:38:44 09/10/2012
// Design Name:   Top
// Module Name:   C:/root/Work/Gauss/Final/Hardware/XUM_Singlecore/MIPS32-Pipelined-Hw/src/Simulation/Top_Tester.v
// Project Name:  MIPS32-Pipelined-Hw
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: Top
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module Top_Tester;

    // Inputs
    reg clock_100MHz;
    reg reset_n;
    reg [7:0] Switch;
    reg UART_Rx;
    reg [1:0] Rotary;

    // Outputs
    wire [14:0] LED;
    wire [6:0] LCD;
    wire UART_Tx;
    wire Piezo;

    // Bidirs
    wire i2c_scl;
    wire i2c_sda;

    // Instantiate the Unit Under Test (UUT)
    Top uut (
        .clock_100MHz(clock_100MHz), 
        .reset_n(reset_n), 
        .Switch(Switch), 
        .LED(LED), 
        .LCD(LCD), 
        .UART_Rx(UART_Rx), 
        .UART_Tx(UART_Tx), 
        .i2c_scl(i2c_scl), 
        .i2c_sda(i2c_sda), 
        .Piezo(Piezo),
        .Rotary(Rotary)
    );
    integer i;

    initial begin
        // Initialize Inputs
        clock_100MHz = 0;
        reset_n = 0;
        Switch = 0;
        UART_Rx = 0;
        Rotary = 0;
        i = 0;

        // Wait 100 ns for global reset to finish
        #100;
        
        // Give time for the PLL to lock
        for (i = 0; i < 50; i = i + 1) begin
            clock_100MHz = ~clock_100MHz;
            #5;
        end
        
        reset_n = 1;
        
        // Add stimulus here
        for (i = 0; i < 2000000000; i = i + 1) begin
            clock_100MHz = ~clock_100MHz;
            #5;
            /*
            // Print instructions which are issued
            if (clock_100MHz & ~uut.clock & uut.MIPS32.Core_InstMem_Ready & uut.MIPS32.Core.ID_Enable) begin
                $display("%h:  %h", uut.MIPS32.Core.ID_Address, uut.MIPS32.Core.Instruction);
            end
            */
        end
    end
      
endmodule

