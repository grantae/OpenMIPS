`timescale 1ns / 1ps
/*
 * File         : PriorityEncoder_16x4_test.v
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
 *   Test module.
 */
module PriorityEncoder_16x4_test;

	// Inputs
	reg [15:0] Encoder_In;

	// Outputs
	wire [3:0] Address_Out;
	wire Match;

	// Instantiate the Unit Under Test (UUT)
	PriorityEncoder_16x4 uut (
		.Encoder_In(Encoder_In),
		.Address_Out(Address_Out),
		.Match(Match)
	);
    integer res;

	initial begin
		// Initialize Inputs
		Encoder_In = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Invalid input
        res = $fopen("result.out");
        check(16'b00000000_00000000, {16{1'bx}}, 0);

        // Single input
        check(16'b00000000_00000001, 0, 1);
        check(16'b00000000_00000010, 1, 1);
        check(16'b00000000_00000100, 2, 1);
        check(16'b00000000_00001000, 3, 1);
        check(16'b00000000_00010000, 4, 1);
        check(16'b00000000_00100000, 5, 1);
        check(16'b00000000_01000000, 6, 1);
        check(16'b00000000_10000000, 7, 1);
        check(16'b00000001_00000000, 8, 1);
        check(16'b00000010_00000000, 9, 1);
        check(16'b00000100_00000000, 10, 1);
        check(16'b00001000_00000000, 11, 1);
        check(16'b00010000_00000000, 12, 1);
        check(16'b00100000_00000000, 13, 1);
        check(16'b01000000_00000000, 14, 1);
        check(16'b10000000_00000000, 15, 1);

        // Multiple inputs, all set
        check(16'b11111111_11111111, 15, 1);
        check(16'b01111111_11111111, 14, 1);
        check(16'b00111111_11111111, 13, 1);
        check(16'b00011111_11111111, 12, 1);
        check(16'b00001111_11111111, 11, 1);
        check(16'b00000111_11111111, 10, 1);
        check(16'b00000011_11111111, 9, 1);
        check(16'b00000001_11111111, 8, 1);
        check(16'b00000000_11111111, 7, 1);
        check(16'b00000000_01111111, 6, 1);
        check(16'b00000000_00111111, 5, 1);
        check(16'b00000000_00011111, 4, 1);
        check(16'b00000000_00001111, 3, 1);
        check(16'b00000000_00000111, 2, 1);
        check(16'b00000000_00000011, 1, 1);

        // Multiple inputs, mixed
        check(16'b10110111_10001110, 15, 1);
        check(16'b01101111_11011111, 14, 1);
        check(16'b00111111_11111110, 13, 1);
        check(16'b00011011_10011111, 12, 1);
        check(16'b00001000_00000001, 11, 1);
        check(16'b00000101_00011110, 10, 1);
        check(16'b00000011_00000000, 9, 1);
        check(16'b00000001_11011011, 8, 1);
        check(16'b00000000_10111110, 7, 1);
        check(16'b00000000_01101010, 6, 1);
        check(16'b00000000_00101010, 5, 1);
        check(16'b00000000_00011011, 4, 1);
        check(16'b00000000_00001101, 3, 1);
        check(16'b00000000_00000101, 2, 1);
        check(16'b00000000_00000010, 1, 1);
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end

    task check;
    input [15:0] tst_in;
    input [3:0]  exp_addr;
    input        exp_match;
    begin
        Encoder_In = tst_in;
        #10;
        if ((Address_Out != exp_addr) | (Match != exp_match)) begin
            $display("Fail: Address_Out: %d (%d expected), Match: %b (%b expected).",
                Address_Out, exp_addr, Match, exp_match);
            $fwrite(res, "0");
            $fclose(res);
            $finish;
        end
    end
    endtask

endmodule

