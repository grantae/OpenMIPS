`timescale 1ns / 1ps
/*
 * File         : EvenOddPage_test.v
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
module EvenOddPage_test;

	// Inputs
	reg [8:0] VPN2_Slice;
	reg [15:0] Mask;

	// Outputs
	wire OddPage;

	// Instantiate the Unit Under Test (UUT)
	EvenOddPage uut (
		.VPN2_Slice(VPN2_Slice), 
		.Mask(Mask), 
		.OddPage(OddPage)
	);
    integer res;

    initial begin
		// Initialize Inputs
		VPN2_Slice = 0;
		Mask = 0;

		// Wait 100 ns for global reset to finish
		#100;

        res = $fopen("result.out");

        // 4KB pages
        test(9'b000000000, 16'h0000, 0);
        test(9'b000000001, 16'h0000, 1);
        test(9'b111111110, 16'h0000, 0);
        test(9'b111111111, 16'h0000, 1);

        // 16KB pages
        test(9'b000000000, 16'h0003, 0);
        test(9'b000100010, 16'h0003, 1);
        test(9'b000100001, 16'h0003, 0);
        test(9'b000000011, 16'h0003, 1);

        // 64KB pages
        test(9'b000000000, 16'h000f, 0);
        test(9'b000000100, 16'h000f, 1);
        test(9'b100000011, 16'h000f, 0);
        test(9'b010000101, 16'h000f, 1);

        // 256KB pages
        test(9'b000000000, 16'h003f, 0);
        test(9'b000001000, 16'h003f, 1);
        test(9'b111110111, 16'h003f, 0);
        test(9'b111111111, 16'h003f, 1);

        // 1MB pages
        test(9'b000000000, 16'h00ff, 0);
        test(9'b000010000, 16'h00ff, 1);
        test(9'b111101111, 16'h00ff, 0);
        test(9'b111111111, 16'h00ff, 1);

        // 4MB pages
        test(9'b000000000, 16'h03ff, 0);
        test(9'b000100000, 16'h03ff, 1);
        test(9'b111011111, 16'h03ff, 0);
        test(9'b111111111, 16'h03ff, 1);

        // 16MB pages
        test(9'b000000000, 16'h0fff, 0);
        test(9'b001000000, 16'h0fff, 1);
        test(9'b110111111, 16'h0fff, 0);
        test(9'b111111111, 16'h0fff, 1);

        // 64MB pages
        test(9'b000000000, 16'h3fff, 0);
        test(9'b010000000, 16'h3fff, 1);
        test(9'b101111111, 16'h3fff, 0);
        test(9'b111111111, 16'h3fff, 1);

        // 256MB pages
        test(9'b000000000, 16'hffff, 0);
        test(9'b100000000, 16'hffff, 1);
        test(9'b011111111, 16'hffff, 0);
        test(9'b111111111, 16'hffff, 1);

        // done
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end

    task test;
    input [8:0]  vpn2_in;
    input [15:0] mask_in;
    input        exp_odd;
    begin
        VPN2_Slice = vpn2_in;
        Mask = mask_in;
        #1;
        if (OddPage != exp_odd) begin
            $display("Fail: OddPage: %b (%b expected).", OddPage, exp_odd);
            $fwrite(res, "0");
            $fclose(res);
            $finish;
        end
    end
    endtask

endmodule

