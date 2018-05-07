`timescale 1ns / 1ps
/*
 * File         : MAddSub_32x32x64_test.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   9-Jan-2015   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Test module.
 */
module DSP_MAddSub_32x32x64_test;
	// Inputs
	reg clock;
	reg reset;
    reg [31:0] A;
    reg [31:0] B;
    reg [63:0] C;
    reg sign;
    reg fused;
    reg subtract;
    reg start;

	// Outputs
	wire busy;
    wire [64:0] D;

	// Instantiate the Unit Under Test (UUT)
	DSP_MAddSub_32x32x64 uut (
		.clock(clock),
		.reset(reset),
        .A(A),
        .B(B),
        .C(C),
        .sign(sign),
        .fused(fused),
        .subtract(subtract),
        .start(start),
        .busy(busy),
        .D(D)
	);
    integer res;
    integer i;

    localparam SIGNED=1'b1, UNSIGNED=1'b0;

    // Always run the clock (100MHz)
    initial forever begin
        #5 clock <= ~clock;
    end

	initial begin
		// Initialize Inputs
		clock = 0;
		reset = 0;
		A = 0;
        B = 0;
        C = 0;
        sign = 0;
        fused = 0;
        subtract = 0;
        start = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
        res = $fopen("result.out");
        do_reset();

        // Multiply unsigned
        mult(UNSIGNED, 32'h1234,     32'h7,        64'h7f6c);
        mult(UNSIGNED, 32'h12345678, 32'hffffffff, 64'h12345677edcba988);
        mult(UNSIGNED, 32'hffffffff, 32'h12345678, 64'h12345677edcba988);
        mult(UNSIGNED, 32'hffffffff, 32'hffffffff, 64'hfffffffe00000001);

        // Multiply signed
        mult(SIGNED,   32'h1234,     32'h7,        64'h7f6c);
        mult(SIGNED,   32'h1234,     32'hfffffff9, 64'hffffffffffff8094);
        mult(SIGNED,   32'hffffedcc, 32'hfffffff9, 64'h7f6c);
        mult(SIGNED,   32'h12345678, 32'hffffffff, 64'hffffffffedcba988);
        mult(SIGNED,   32'hffffffff, 32'h12345678, 64'hffffffffedcba988);
        mult(SIGNED,   32'hffffffff, 32'hffffffff, 64'h1);

        // Multiply random bag
        mult(UNSIGNED,  32'd2,         32'd3,         64'd6);
        mult(SIGNED,    32'd2,        -32'd3,        -64'd6);
        mult(UNSIGNED,  32'hdeaf,      32'hbeef,      65'ha615c761);
        mult(SIGNED,    32'hdeaf,     -32'hbeef,     -65'ha615c761);
        mult(SIGNED,   -32'hdeaf,     -32'hbeef,      65'ha615c761);
        mult(UNSIGNED,  32'h123456,    32'h7654321,   65'h86a1c5f94116);
        mult(UNSIGNED,  32'h7fffffff,  32'hcccccccc,  65'h6666666533333334);

        // Fused Multiply/Add
        madd(UNSIGNED, 32'h5,        32'h7,        64'd80,               65'd115);
        madd(UNSIGNED, 32'hdeaf,     32'hbeef,     64'h0edcba9876543210, 65'h0edcba991c69f971);
        madd(SIGNED,   32'hffffffff, 32'hffffffff, 64'hffffffffffffffff, 65'h0);
        madd(UNSIGNED, 32'h1,        32'h1,        64'hffffffffffffffff, 65'h10000000000000000);
        madd(UNSIGNED, 32'hffffffff, 32'hffffffff, 64'h1fffffffe,        65'h0ffffffffffffffff);
        madd(UNSIGNED, 32'hffffffff, 32'hffffffff, 64'hffffffffffffffff, 65'h1fffffffe00000000);
        madd(SIGNED,   32'd16777216, 32'd100000,   -64'd2000000000000,   -65'd322278400000);

        // Fused Multiply/Sub
        msub(UNSIGNED, 32'h5,        32'h7,        64'd80,               65'd45);
        msub(UNSIGNED, 32'hdeaf,     32'hbeef,     64'h0edcba9876543210, 65'hedcba97d03e6aaf);
        msub(SIGNED,   32'hffffffff, 32'hffffffff, 64'hffffffffffffffff, 65'h1fffffffffffffffe);
        msub(UNSIGNED, 32'h1,        32'h1,        64'hffffffffffffffff, 65'h0fffffffffffffffe);
        msub(UNSIGNED, 32'hffffffff, 32'hffffffff, 64'h1fffffffe,        65'h100000003fffffffd);
        msub(UNSIGNED, 32'hffffffff, 32'hffffffff, 64'hffffffffffffffff, 65'h1fffffffe);
        msub(SIGNED,   32'd16777216, 32'd100000,   -64'd2000000000000,   65'h1fffffca7b6b5e000);

        // Interrupted operation
        mult_interrupted(UNSIGNED, 32'h12345678, 32'hffffffff, 32'h1234, 32'h7, 64'h7f6c);

        // Retain the result
        msub_retain(SIGNED, 32'd16777216, 32'd100000, -64'd2000000000000, 65'h1fffffca7b6b5e000);

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
	end

    // Task Multiply
    task mult;
    input s;
    input [31:0] a;
    input [31:0] b;
    input [63:0] exp_d;
    begin
        @(posedge clock) begin
            A <= a;
            B <= b;
            sign <= s;
            fused <= 1'b0;
            start <= 1'b1;
        end
        @(posedge clock) begin
            start <= 1'b0;
        end
        @(posedge clock);
        wait_free();
        check_result64(exp_d);
    end
    endtask

    // Task Fused Multiply/Add
    task madd;
    input s;
    input [31:0] a;
    input [31:0] b;
    input [63:0] c;
    input [64:0] exp_d;
    begin
        @(posedge clock) begin
            A <= a;
            B <= b;
            C <= c;
            sign <= s;
            fused <= 1'b1;
            subtract <= 1'b0;
            start <= 1'b1;
        end
        @(posedge clock) begin
            start <= 1'b0;
        end
        @(posedge clock);
        wait_free();
        check_result65(exp_d);
    end
    endtask

    // Task Fused Multiply/Subtract
    task msub;
    input s;
    input [31:0] a;
    input [31:0] b;
    input [63:0] c;
    input [64:0] exp_d;
    begin
        @(posedge clock) begin
            A <= a;
            B <= b;
            C <= c;
            sign <= s;
            fused <= 1'b1;
            subtract <= 1'b1;
            start <= 1'b1;
        end
        @(posedge clock) begin
            start <= 1'b0;
        end
        @(posedge clock);
        wait_free();
        check_result65(exp_d);
    end
    endtask

    // Task interrupted Multiply
    task mult_interrupted;
    input s;
    input [31:0] a1;
    input [31:0] b1;
    input [31:0] a2;
    input [31:0] b2;
    input [63:0] exp_d;
    begin
        @(posedge clock) begin
            A <= a1;
            B <= b1;
            sign <= s;
            fused <= 1'b0;
            start <= 1'b1;
        end
        @(posedge clock) begin
            start <= 1'b0;
        end
        // wait a couple of cycles (must be less than completion time)
        @(posedge clock);
        @(posedge clock);
        @(posedge clock) begin
            if (~busy) begin
                $display("Fail: Need to adjust 'mult_interrupted' to interrupt while busy.");
                fail();
            end
            A <= a2;
            B <= b2;
            start <= 1'b1;
        end
        @(posedge clock) begin
            start <= 1'b0;
        end
        @(posedge clock);
        wait_free();
        check_result64(exp_d);
    end
    endtask

    // Task retain result
    task msub_retain;
    input s;
    input [31:0] a;
    input [31:0] b;
    input [63:0] c;
    input [64:0] exp_d;
    begin
        msub(s, a, b, c, exp_d);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        check_result65(exp_d);
    end
    endtask

    // Task check result (multiply only)
    task check_result64;
    input [63:0] exp_result;
    begin
        if (D[63:0] != exp_result) begin
            $display("Fail: D: %h (%h expected).", D[63:0], exp_result);
            fail();
        end
    end
    endtask

    // Task check result (fused multiply/add/sub)
    task check_result65;
    input [64:0] exp_result;
    begin
        if (D != exp_result) begin
            $display("Fail: D: %h (%h expected).", D, exp_result);
            fail();
        end
    end
    endtask

    // Task wait for free (not busy) (up to 100 cycles)
    task wait_free;
    begin
        i = 0;
        while (busy & (i < 100)) begin
            @(posedge clock);
            i = i + 1;
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
        $finish;
    end
    endtask

endmodule

