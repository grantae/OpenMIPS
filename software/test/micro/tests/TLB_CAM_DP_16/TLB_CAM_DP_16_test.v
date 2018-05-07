`timescale 1ns / 1ps
/*
 * File         : TLB_CAM_DP_16_test.v
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
module TLB_CAM_DP_16_test;

	// Inputs
	reg clock;
	reg reset;
	reg [3:0] Idx_Index;
	reg Idx_Write;
	reg [18:0] Idx_VPN2;
	reg [15:0] Idx_Mask;
	reg [7:0] Idx_ASID;
	reg Idx_G;
	reg [19:0] VPN_A;
	reg [7:0] ASID_A;
	reg [19:0] VPN_B;
	reg [7:0] ASID_B;

	// Outputs
	wire [18:0] Idx_VPN2_Out;
	wire [15:0] Idx_Mask_Out;
	wire [7:0] Idx_ASID_Out;
	wire Idx_G_Out;
	wire Hit_A;
	wire [3:0] Index_A;
	wire OddPage_A;
    wire [15:0] Mask_A;
	wire Hit_B;
	wire [3:0] Index_B;
	wire OddPage_B;
    wire [15:0] Mask_B;

	// Instantiate the Unit Under Test (UUT)
	TLB_CAM_DP_16 uut (
		.clock(clock),
		.Idx_Index(Idx_Index),
		.Idx_Write(Idx_Write),
		.Idx_VPN2(Idx_VPN2),
		.Idx_Mask(Idx_Mask),
		.Idx_ASID(Idx_ASID),
		.Idx_G(Idx_G),
		.Idx_VPN2_Out(Idx_VPN2_Out),
		.Idx_Mask_Out(Idx_Mask_Out),
		.Idx_ASID_Out(Idx_ASID_Out),
		.Idx_G_Out(Idx_G_Out),
		.VPN_A(VPN_A),
		.ASID_A(ASID_A),
		.Hit_A(Hit_A),
		.Index_A(Index_A),
		.OddPage_A(OddPage_A),
        .Mask_A(Mask_A),
		.VPN_B(VPN_B),
		.ASID_B(ASID_B),
		.Hit_B(Hit_B),
		.Index_B(Index_B),
		.OddPage_B(OddPage_B),
        .Mask_B(Mask_B)
	);
    integer res;

    // Always run the clock (100MHz)
    initial forever begin
        #5 clock <= ~clock;
    end

	initial begin
		// Initialize Inputs
		clock = 0;
		reset = 0;
		Idx_Index = 0;
		Idx_Write = 0;
		Idx_VPN2 = 0;
		Idx_Mask = 0;
		Idx_ASID = 0;
		Idx_G = 0;
		VPN_A = 0;
		ASID_A = 0;
		VPN_B = 0;
		ASID_B = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
        res = $fopen("result.out");
        do_reset();

        // Write entries (idx, vpn2_in, vpn2_expected, mask, asid, g)
        write(0,  19'h0aaa0, 19'h0aaa0, 16'h0000, 8'd100, 0);
        write(1,  19'h0aaa1, 19'h0aaa1, 16'h0000, 8'd100, 0);
        write(2,  19'h06c6d, 19'h06c6c, 16'h0003, 8'd200, 0);
        write(3,  19'h16c6c, 19'h16c60, 16'h000f, 8'd200, 0);
        write(4,  19'h26c6c, 19'h26c40, 16'h003f, 8'd200, 0);
        write(5,  19'h36c6c, 19'h36c00, 16'h00ff, 8'd200, 0);
        write(6,  19'h46c6c, 19'h46c00, 16'h03ff, 8'd200, 0);
        write(7,  19'h56c6c, 19'h56000, 16'h0fff, 8'd200, 0);
        write(8,  19'h66c6c, 19'h64000, 16'h3fff, 8'd200, 0);
        write(9,  19'h76c6c, 19'h70000, 16'hffff, 8'd200, 0);
        write(10, 19'h0aaaa, 19'h0aaaa, 16'h0000, 8'd000, 1);

        // Checks:(vpn, asid, match?, index? oddpage?)

        // Miss
        checkA(20'h00000, 8'd100, 0, 4'bxxxx, 1'bx);
        checkA(20'hed8d8, 8'd100, 0, 4'bxxxx, 1'bx);
        checkB(20'h15540, 8'd001, 0, 4'bxxxx, 1'bx);

        // VPN 4KB hit
        checkA({19'h0aaa0, 1'b0}, 8'd100, 1, 0, 0);
        checkA({19'h0aaa0, 1'b1}, 8'd100, 1, 0, 1);
        checkB({19'h0aaa0, 1'b0}, 8'd100, 1, 0, 0);
        checkB({19'h0aaa0, 1'b1}, 8'd100, 1, 0, 1);

        // VPN large page hit
        checkA({19'h06c6c, 1'b0}, 8'd200, 1, 2, 0);
        checkB({19'h06c6c, 1'b1}, 8'd200, 1, 2, 0);
        checkA({19'h16c68, 1'b0}, 8'd200, 1, 3, 1);
        checkB({19'h16c68, 1'b1}, 8'd200, 1, 3, 1);
        checkA({19'h26c60, 1'b0}, 8'd200, 1, 4, 1);
        checkB({19'h26c60, 1'b1}, 8'd200, 1, 4, 1);
        checkA({19'h36c60, 1'b0}, 8'd200, 1, 5, 0);
        checkB({19'h36c60, 1'b1}, 8'd200, 1, 5, 0);
        checkA({19'h46c00, 1'b0}, 8'd200, 1, 6, 0);
        checkB({19'h46c00, 1'b1}, 8'd200, 1, 6, 0);
        checkA({19'h56c00, 1'b0}, 8'd200, 1, 7, 1);
        checkB({19'h56c00, 1'b1}, 8'd200, 1, 7, 1);
        checkA({19'h66000, 1'b0}, 8'd200, 1, 8, 1);
        checkB({19'h66000, 1'b1}, 8'd200, 1, 8, 1);
        checkA({19'h76000, 1'b0}, 8'd200, 1, 9, 0);
        checkB({19'h76000, 1'b1}, 8'd200, 1, 9, 0);

        // ASID hit/miss
        checkB({19'h0aaa0, 1'b0}, 8'd000, 0, 4'bxxxx, 1'bx);
        checkA({19'h0aaaa, 1'b0}, 8'd032, 1, 10, 0);
        checkB({19'h76c6c, 1'b0}, 8'd100, 0, 4'bxxxx, 1'bx);

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end

    // Task write
    task write;
    input [3:0] index_in;
    input [18:0] vpn2_in;
    input [18:0] vpn2_exp;
    input [15:0] mask_in;
    input [7:0] asid_in;
    input       g_in;
    begin
        @(posedge clock) begin
            Idx_Index <= index_in;
            Idx_VPN2 <= vpn2_in;
            Idx_Mask <= mask_in;
            Idx_ASID <= asid_in;
            Idx_G <= g_in;
            Idx_Write <= 1;
        end
        @(posedge clock) begin
            Idx_Write <= 0;
        end
        @(negedge clock);
        if (Idx_VPN2_Out != vpn2_exp) begin
            $display("Fail: Idx_VPN2_Out: %d (%d expected).", Idx_VPN2_Out, vpn2_exp);
            fail();
        end
    end
    endtask

    // Task check on port A
    task checkA;
    input [19:0] vpn_in;
    input [7:0]  asid_in;
    input exp_match;
    input [3:0] exp_index;
    input exp_oddpage;
    begin
        @(posedge clock) begin
            VPN_A <= vpn_in;
            ASID_A <= asid_in;
        end
        @(negedge clock);
        if (Hit_A != exp_match) begin
            $display("Fail: Hit_A: %b (%b expected).", Hit_A, exp_match);
            fail();
        end
        if (Index_A != exp_index) begin
            $display("Fail: Index_A: %d (%d expected).", Index_A, exp_index);
            fail();
        end
        if (OddPage_A != exp_oddpage) begin
            $display("Fail: OddPage_A: %b (%b expected).", OddPage_A, exp_oddpage);
            fail();
        end
    end
    endtask

    // Task check on port B
    task checkB;
    input [19:0] vpn_in;
    input [7:0]  asid_in;
    input exp_match;
    input [3:0] exp_index;
    input exp_oddpage;
    begin
        @(posedge clock) begin
            VPN_B <= vpn_in;
            ASID_B <= asid_in;
        end
        @(negedge clock);
        if (Hit_B != exp_match) begin
            $display("Fail: Hit_B: %b (%b expected).", Hit_B, exp_match);
            fail();
        end
        if (Index_B != exp_index) begin
            $display("Fail: Index_B: %d (%d expected).", Index_B, exp_index);
            fail();
        end
        if (OddPage_B != exp_oddpage) begin
            $display("Fail: OddPage_B: %b (%b expected).", OddPage_B, exp_oddpage);
            fail();
        end
    end
    endtask

    // Task cycle
    task cycle;
    begin
        @(posedge clock);
    end
    endtask

    // Task reset
    task do_reset;
    begin
        @(posedge clock) reset <= 1'b1;
        @(posedge clock) reset <= 1'b0;
    end
    endtask

    // Task terminate on failure
    task fail;
    begin
        $fwrite(res, "0");
        $fclose(res);
        @(posedge clock);
        $finish;
    end
    endtask

endmodule

