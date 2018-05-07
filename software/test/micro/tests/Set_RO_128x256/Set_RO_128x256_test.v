`timescale 1ns / 1ps
/*
 * File         : Set_RO_128x256_test.v
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
module Set_RO_128x256_test;

	// Inputs
	reg clock;
	reg reset;
	reg [23:0] Tag;
	reg [7:0] Index;
	reg [1:0] Offset;
	reg [7:0] LineIndex;
	reg [1:0] LineOffset;
	reg [31:0] LineIn;
	reg ValidateLine;
	reg InvalidateLine;
	reg FillLine;
	reg StoreTag;
	reg [25:0] StoreTagData;

	// Outputs
	wire [31:0] WordOut;
	wire Hit;
	wire Valid;

	// Instantiate the Unit Under Test (UUT)
	Set_RO_128x256 #(
        .PABITS(36))
        uut (
		.clock(clock),
		.reset(reset),
		.Tag(Tag),
		.Index(Index),
		.Offset(Offset),
		.LineIndex(LineIndex),
		.LineOffset(LineOffset),
		.WordOut(WordOut),
		.Hit(Hit),
		.Valid(Valid),
		.LineIn(LineIn),
		.ValidateLine(ValidateLine),
		.InvalidateLine(InvalidateLine),
		.FillLine(FillLine),
		.StoreTag(StoreTag),
		.StoreTagData(StoreTagData)
	);
    integer res;

    localparam [23:0] tag1 = 24'h654321;
    localparam [23:0] tag2 = 24'hcccccc;

    localparam [31:0] l1w0 = 32'h11111111;
    localparam [31:0] l1w1 = 32'h22222222;
    localparam [31:0] l1w2 = 32'h33333333;
    localparam [31:0] l1w3 = 32'h44444444;
    localparam [31:0] l2w0 = 32'h77777777;
    localparam [31:0] l2w1 = 32'h88888888;
    localparam [31:0] l2w2 = 32'h99999999;
    localparam [31:0] l2w3 = 32'haaaaaaaa;

    localparam [127:0] l1  = {l1w0, l1w1, l1w2, l1w3};
    localparam [127:0] l2  = {l2w0, l2w1, l2w2, l2w3};

	initial begin
		// Initialize Inputs
		clock = 0;
		reset = 0;
		Tag = 0;
		Index = 0;
		Offset = 0;
		LineIndex = 0;
		LineOffset = 0;
		LineIn = 0;
		ValidateLine = 0;
		InvalidateLine = 0;
		FillLine = 0;
		StoreTag = 0;
		StoreTagData = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
        res = $fopen("result.out");
        do_reset();

        // Validate cache lines
        validate(tag1, 8'h76);
        validate(tag2, 8'h77);

        // Store tag
        store_tag(tag1, 2'b00, 8'h86);
        store_tag(tag2, 2'b01, 8'h87);

        // Invalidate cache lines
        invalidate(tag1, 8'h76);
        invalidate(tag2, 8'h77);
        invalidate(tag1, 8'hff);
        store_tag(tag2, 2'b00, 8'hff);  // invalid
        store_tag(tag1, 2'b11, 8'hfe);  // valid
        validate(tag1, 8'h76);
        validate(tag2, 8'h77);

        // Fill line (not a test)
        fill_line(8'h76, l1);
        fill_line(8'h77, l2);
        fill_line(8'hff, l2);   // invalid
        fill_line(8'hfe, l1);   // valid

        // Read words
        read_words(tag1, 8'h76, 2'b01, l1w1, 1'b1, 1'b1, tag1, 8'h76, 2'b10, l1w2, 1'b1, 1'b1); // t1idx1 hit,  t1idx2 hit
        read_words(tag1, 8'h76, 2'b00, l1w0, 1'b1, 1'b1, tag1, 8'h76, 2'b11, l1w3, 1'b1, 1'b1); // t1idx0 hit,  t1idx3 hit
        read_words(tag1, 8'h76, 2'b11, l1w3, 1'b1, 1'b1, tag2, 8'h77, 2'b00, l2w0, 1'b1, 1'b1); // t0idx3 hit,  t2idx0 hit
        read_words(tag2, 8'hff, 2'b00, l2w0, 1'b0, 1'b0, tag1, 8'h76, 2'b10, l1w2, 1'b1, 1'b1); // t2idx0 miss, t1idx2 hit
        read_words(tag1, 8'h77, 2'b11, l2w3, 1'b0, 1'b1, tag2, 8'h77, 2'b11, l2w3, 1'b1, 1'b1); // t1idx3 miss, t3idx3 hit
        read_words(tag1, 8'hfe, 2'b00, l1w0, 1'b1, 1'b1, tag2, 8'hfe, 2'b01, l1w1, 1'b0, 1'b1); // t1idx0 hit,  t2idx1 miss

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end

    // Task store tag
    task store_tag;
    input [23:0] tag_in;
    input [1:0] v_in;
    input [7:0] idx_in;
    begin
        StoreTagData = {tag_in, v_in};
        Tag = tag_in;   // for comparison
        Index = idx_in;
        StoreTag = 1'b1;
        cycle();
        check_tag_out(|v_in, |v_in);
        StoreTag = 1'b0;
    end
    endtask

    // Task validate
    task validate;
    input [23:0] tag_in;
    input [7:0] idx_in;
    begin
        Tag = tag_in;
        Index = idx_in;
        ValidateLine = 1'b1;
        cycle();
        check_tag_out(1'b1, 1'b1);
        ValidateLine = 1'b0;
    end
    endtask

    // Task invalidate
    task invalidate;
    input [23:0] tag_in;
    input [7:0] idx_in;
    begin
        Tag = tag_in;
        Index = idx_in;
        InvalidateLine = 1'b1;
        cycle();
        check_tag_out(1'b0, 1'b0);
        InvalidateLine = 1'b0;
    end
    endtask

    // Task check tag out: current output data
    task check_tag_out;
    input exp_h;
    input exp_v;
    begin
        if (Valid != exp_v) begin
            $display("Fail: Valid: %b (%b expected).", Valid, exp_v);
            fail();
        end
        if (Hit != exp_h) begin
            $display("Fail: Hit: %b (%b expected).", Hit, exp_h);
            fail();
        end
    end
    endtask

    // Task check word out: current output data
    task check_word_out;
    input [31:0] exp_word;
    begin
        if (WordOut != exp_word) begin
            $display("Fail: WordOut: %h (%h expected).", WordOut, exp_word);
            fail();
        end
    end
    endtask

    // Task fill line
    task fill_line;
    input [7:0] idx_in;
    input [127:0] line_in;
    begin
        LineIndex = idx_in;
        LineOffset = 2'b00;
        LineIn = line_in[127:96];
        FillLine = 1'b1;
        cycle();
        FillLine = 1'b0;    // skip one cycle for fun
        cycle();
        FillLine = 1'b1;
        LineIn = line_in[95:64];
        LineOffset = 2'b01;
        cycle();
        LineIn = line_in[64:32];
        LineOffset = 2'b10;
        cycle();
        LineIn = line_in[31:0];
        LineOffset = 2'b11;
        cycle();
        FillLine = 1'b0;
    end
    endtask

    // Task read words (pipelined)
    task read_words;
    input [23:0] tag1_in;
    input [7:0] idx1_in;
    input [1:0] offset1_in;
    input [31:0] exp_word1;
    input exp_h1;
    input exp_v1;
    input [23:0] tag2_in;
    input [7:0] idx2_in;
    input [1:0] offset2_in;
    input [31:0] exp_word2;
    input exp_h2;
    input exp_v2;
    begin
        Tag = tag1_in;
        Index = idx1_in;
        Offset = offset1_in;
        cycle();
        check_tag_out(exp_h1, exp_v1);
        check_word_out(exp_word1);
        Tag = tag2_in;
        Index = idx2_in;
        Offset = offset2_in;
        cycle();
        check_tag_out(exp_h2, exp_v2);
        check_word_out(exp_word2);
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

