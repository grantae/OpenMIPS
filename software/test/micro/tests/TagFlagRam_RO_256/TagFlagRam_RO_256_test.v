`timescale 1ns / 1ps
/*
 * File         : TagFlagRam_RO_256_test.v
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
module TagFlagRam_RO_256_test;

	// Inputs
    reg clock;
    reg reset;
    reg [7:0] Index;
    reg [23:0] Tag_Cmp;
    reg [23:0] Tag_Set;
    reg Write;
    reg Valid;

	// Outputs
	wire MatchHit;
    wire MatchValid;

	// Instantiate the Unit Under Test (UUT)
	TagFlagRam_RO_256 #(
        .PABITS(36))
        uut (
        .clock(clock),
        .reset(reset),
        .Index(Index),
        .Tag_Cmp(Tag_Cmp),
        .Tag_Set(Tag_Set),
        .Write(Write),
        .Valid(Valid),
        .MatchHit(MatchHit),
        .MatchValid(MatchValid)
	);
    integer res;

    localparam [23:0] tag1 = 24'h123456;
    localparam [23:0] tag2 = 24'h333333;
    localparam [23:0] tag3 = 24'hffffff;
    localparam [23:0] tag4 = 24'h000001;

    localparam [24:0] entry1i = {tag1, 1'b0};
    localparam [24:0] entry1v = {tag1, 1'b1};
    localparam [24:0] entry2i = {tag2, 1'b0};
    localparam [24:0] entry2v = {tag2, 1'b1};
    localparam [24:0] entry3i = {tag3, 1'b0};
    localparam [24:0] entry3v = {tag3, 1'b1};
    localparam [24:0] entry4i = {tag4, 1'b0};
    localparam [24:0] entry4v = {tag4, 1'b1};

    initial begin
		// Initialize Inputs
		clock = 0;
        reset = 0;
        Index = 0;
        Tag_Cmp = 0;
        Tag_Set = 0;
        Write = 0;
        Valid = 0;

		// Wait 100 ns for global reset to finish
		#100;

        // Add stimulus here
        res = $fopen("result.out");
        do_reset();

        // Write and verify tags
        write_tag(8'h2, entry1i);
        write_tag(8'h3, entry1v);
        write_tag(8'h10, entry2i);
        write_tag(8'h11, entry2v);
        write_tag(8'hcc, entry3i);
        write_tag(8'hcd, entry3v);
        write_tag(8'hed, entry4i);
        write_tag(8'hee, entry4v);

        // Check tags
        check_tags(tag1, 8'h3,  1'b1, 1'b1, tag2, 8'h11, 1'b1, 1'b1, tag3, 8'hcd, 1'b1, 1'b1);  // all hit, valid
        check_tags(tag1, 8'h70, 1'b0, 1'b0, tag2, 8'h71, 1'b0, 1'b0, tag3, 8'h72, 1'b0, 1'b0);  // all miss, invalid
        check_tags(tag1, 8'h11, 1'b0, 1'b1, tag2, 8'hee, 1'b0, 1'b1, tag3, 8'h11, 1'b0, 1'b1);  // all miss, valid
        check_tags(tag1, 8'haa, 1'b0, 1'b0, tag2, 8'h11, 1'b1, 1'b1, tag3, 8'hee, 1'b0, 1'b1);  // miss_i->hit->miss_v

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end


    // Task check_tag
    task check_tags;
    input [23:0] tag1_in;
    input [7:0] idx1_in;
    input exp_h1;
    input exp_v1;
    input [23:0] tag2_in;
    input [7:0] idx2_in;
    input exp_h2;
    input exp_v2;
    input [23:0] tag3_in;
    input [7:0] idx3_in;
    input exp_h3;
    input exp_v3;
    begin
        Tag_Cmp = tag1_in;
        Index = idx1_in;
        cycle();
        check_out(exp_h1, exp_v1);
        Tag_Cmp = tag2_in;
        Index = idx2_in;
        cycle();
        check_out(exp_h2, exp_v2);
        Tag_Cmp = tag3_in;
        Index = idx3_in;
        cycle();
        check_out(exp_h3, exp_v3);
    end
    endtask

    // Task write_tag: Write then verify a tag entry
    task write_tag;
    input [7:0] idx_in;
    input [24:0] entry_in;
    begin
        Index = idx_in;
        Tag_Cmp = entry_in[24:1];
        Tag_Set = entry_in[24:1];
        Valid = entry_in[0];
        Write = 1;
        cycle();
        check_out(MatchValid, entry_in[0]); // write-first
        Write = 0;
        Valid = 0;
        cycle();
        check_out(MatchValid, entry_in[0]);
    end
    endtask

    // Task check current outputs
    task check_out;
    input exp_h;
    input exp_v;
    begin
        if (MatchValid != exp_v) begin
            $display("Fail: Valid %b (%b expected).", MatchValid, exp_v);
            fail();
        end
        if (MatchHit != exp_h) begin
            $display("Fail: Hit %b (%b expected).", MatchHit, exp_h);
            fail();
        end
    end
    endtask

    // Task cycle
    task cycle;
    begin
        #1;
        clock = 1;
        #1;
        clock = 0;
    end
    endtask

    // Task reset
    task do_reset;
    begin
        reset = 1;
        #2;
        cycle();
        reset = 0;
    end
    endtask

    // Task terminate on failure
    task fail;
    begin
        $fwrite(res, "0");
        $fclose(res);
        $finish;
    end
    endtask

endmodule

