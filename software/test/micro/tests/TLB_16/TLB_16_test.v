`timescale 1ns / 1ps
/*
 * File         : TLBCAM_DP_16_test.v
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
module TLB_16_test;
	// Inputs
	reg clock;
	reg reset;
	reg [19:0] VPN_I;
	reg [7:0] ASID_I;
	reg Stall_I;
	reg [19:0] VPN_D;
	reg [7:0] ASID_D;
	reg Stall_D;
	reg [3:0] Index_In;
	reg [18:0] VPN2_In;
	reg [15:0] Mask_In;
	reg [7:0] ASID_In;
	reg G_In;
	reg [23:0] PFN0_In;
	reg [2:0] C0_In;
	reg D0_In;
	reg V0_In;
	reg [23:0] PFN1_In;
	reg [2:0] C1_In;
	reg D1_In;
	reg V1_In;
	reg Read;
	reg Write;
	reg Useg_MC;
	reg [2:0] Kseg0_C;

	// Outputs
	wire Hit_I;
	wire [23:0] PFN_I;
	wire [2:0] Cache_I;
	wire Dirty_I;
	wire Valid_I;
	wire Hit_D;
	wire [23:0] PFN_D;
	wire [2:0] Cache_D;
	wire Dirty_D;
	wire Valid_D;
	wire [3:0] Index_Out;
	wire [18:0] VPN2_Out;
	wire [15:0] Mask_Out;
	wire [7:0] ASID_Out;
	wire G_Out;
	wire [23:0] PFN0_Out;
	wire [2:0] C0_Out;
	wire D0_Out;
	wire V0_Out;
	wire [23:0] PFN1_Out;
	wire [2:0] C1_Out;
	wire D1_Out;
	wire V1_Out;

	// Instantiate the Unit Under Test (UUT)
	TLB_16 #(.PABITS(36)) uut (
		.clock(clock),
		.reset(reset),
		.VPN_I(VPN_I),
		.ASID_I(ASID_I),
		.Hit_I(Hit_I),
		.PFN_I(PFN_I),
		.Cache_I(Cache_I),
		.Dirty_I(Dirty_I),
		.Valid_I(Valid_I),
		.Stall_I(Stall_I),
		.VPN_D(VPN_D),
		.ASID_D(ASID_D),
		.Hit_D(Hit_D),
		.PFN_D(PFN_D),
		.Cache_D(Cache_D),
		.Dirty_D(Dirty_D),
		.Valid_D(Valid_D),
		.Stall_D(Stall_D),
		.Index_In(Index_In),
		.VPN2_In(VPN2_In),
		.Mask_In(Mask_In),
		.ASID_In(ASID_In),
		.G_In(G_In),
		.PFN0_In(PFN0_In),
		.C0_In(C0_In),
		.D0_In(D0_In),
		.V0_In(V0_In),
		.PFN1_In(PFN1_In),
		.C1_In(C1_In),
		.D1_In(D1_In),
		.V1_In(V1_In),
		.Index_Out(Index_Out),
		.VPN2_Out(VPN2_Out),
		.Mask_Out(Mask_Out),
		.ASID_Out(ASID_Out),
		.G_Out(G_Out),
		.PFN0_Out(PFN0_Out),
		.C0_Out(C0_Out),
		.D0_Out(D0_Out),
		.V0_Out(V0_Out),
		.PFN1_Out(PFN1_Out),
		.C1_Out(C1_Out),
		.D1_Out(D1_Out),
		.V1_Out(V1_Out),
		.Read(Read),
		.Write(Write),
		.Useg_MC(Useg_MC),
		.Kseg0_C(Kseg0_C)
	);
    integer res;
    integer i;

    // TLB Entry: VPN2, Mask, ASID, G, PFN0, C0, D0, V0, PFN1, C1, D1, V1
    localparam [101:0] useg_4K_p0_entry      = {19'h11a2b, 16'h000,  8'h0, 1'b0, 24'h987654, 3'b000, 1'b0, 1'b0, 24'h123456, 3'b000, 1'b1, 1'b1};
    localparam [101:0] useg_4M_p1_entry      = {19'h198ca, 16'h3ff,  8'h1, 1'b0, 24'h555400, 3'b011, 1'b1, 1'b1, 24'h777800, 3'b000, 1'b0, 1'b1};
    localparam [101:0] useg_4K_g_entry       = {19'h77777, 16'h000,  8'h2, 1'b1, 24'h666666, 3'b111, 1'b0, 1'b1, 24'h888888, 3'b001, 1'b1, 1'b1};
    localparam [101:0] useg_256M_g_entry     = {19'h20fff, 16'hffff, 8'h3, 1'b1, 24'h120000, 3'b111, 1'b1, 1'b1, 24'h780000, 3'b111, 1'b1, 1'b1};

    // Expected TLB entries. These may be different due to VPN2 masking
    localparam [101:0] useg_4K_p0_entry_exp  = {19'h11a2b, 16'h000,  8'h0, 1'b0, 24'h987654, 3'b000, 1'b0, 1'b0, 24'h123456, 3'b000, 1'b1, 1'b1};
    localparam [101:0] useg_4M_p1_entry_exp  = {19'h19800, 16'h3ff,  8'h1, 1'b0, 24'h555400, 3'b011, 1'b1, 1'b1, 24'h777800, 3'b000, 1'b0, 1'b1};
    localparam [101:0] useg_4K_g_entry_exp   = {19'h77777, 16'h000,  8'h2, 1'b1, 24'h666666, 3'b111, 1'b0, 1'b1, 24'h888888, 3'b001, 1'b1, 1'b1};
    localparam [101:0] useg_256M_g_entry_exp = {19'h20000, 16'hffff, 8'h3, 1'b1, 24'h120000, 3'b111, 1'b1, 1'b1, 24'h780000, 3'b111, 1'b1, 1'b1};

    // Virtual Address: VPN, ASID
    localparam [27:0] useg_4K_p0_evaddr      = {20'h23456, 8'h00};
    localparam [27:0] useg_4K_p0_ovaddr      = {20'h23457, 8'h00};
    localparam [27:0] useg_4M_p1_evaddr      = {20'h333f4, 8'h01};
    localparam [27:0] useg_4M_p1_ovaddr      = {20'h334ab, 8'h01};
    localparam [27:0] useg_4K_g_evaddr       = {20'heeeee, 8'h07};
    localparam [27:0] useg_4K_g_ovaddr       = {20'heeeef, 8'h07};
    localparam [27:0] useg_256M_g_evaddr     = {20'h4abcd, 8'h08};
    localparam [27:0] useg_256M_g_ovaddr     = {20'h5abcd, 8'h08};
    localparam [27:0] useg_4K_p0_m1vaddr     = {20'h00200, 8'h00};  // miss
    localparam [27:0] useg_4K_p0_m2vaddr     = {20'h23456, 8'hff};  // miss
    localparam [27:0] kseg0_vaddr1           = {20'h80001, 8'hff};
    localparam [27:0] kseg0_vaddr2           = {20'h9f020, 8'h00};
    localparam [27:0] kseg1_vaddr1           = {20'ha0011, 8'hff};
    localparam [27:0] kseg1_vaddr2           = {20'hbf030, 8'h00};

    // Physical Address: PFN, Cache, Dirty, Valid
    localparam [28:0] useg_4K_p0_epaddr      = {24'h987654, 3'b000, 1'b0, 1'b0};
    localparam [28:0] useg_4K_p0_opaddr      = {24'h123456, 3'b000, 1'b1, 1'b1};
    localparam [28:0] useg_4M_p1_epaddr      = {24'h5557f4, 3'b011, 1'b1, 1'b1};
    localparam [28:0] useg_4M_p1_opaddr      = {24'h7778ab, 3'b000, 1'b0, 1'b1};
    localparam [28:0] useg_4K_g_epaddr       = {24'h666666, 3'b111, 1'b0, 1'b1};
    localparam [28:0] useg_4K_g_opaddr       = {24'h888888, 3'b001, 1'b1, 1'b1};
    localparam [28:0] useg_256M_g_epaddr     = {24'h12abcd, 3'b111, 1'b1, 1'b1};
    localparam [28:0] useg_256M_g_opaddr     = {24'h78abcd, 3'b111, 1'b1, 1'b1};
    localparam [23:0] kseg0_paddr1           = {24'h000001};
    localparam [23:0] kseg0_paddr2           = {24'h01f020};
    localparam [23:0] kseg1_paddr1           = {24'h000011};
    localparam [23:0] kseg1_paddr2           = {24'h01f030};


    // Always run the clock (100MHz)
    initial forever begin
        #5 clock <= ~clock;
    end

	initial begin
		// Initialize Inputs
		clock = 0;
		reset = 0;
		VPN_I = 0;
		ASID_I = 0;
		Stall_I = 0;
		VPN_D = 0;
		ASID_D = 0;
		Stall_D = 0;
		Index_In = 0;
		VPN2_In = 0;
		Mask_In = 0;
		ASID_In = 0;
		G_In = 0;
		PFN0_In = 0;
		C0_In = 0;
		D0_In = 0;
		V0_In = 0;
		PFN1_In = 0;
		C1_In = 0;
		D1_In = 0;
		V1_In = 0;
		Read = 0;
		Write = 0;
		Useg_MC = 0;
		Kseg0_C = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
        res = $fopen("result.out");
        do_reset();

        // Start with mapped/cached useg and cached kseg0
        Useg_MC = 1;
        Kseg0_C = 1;

        // Initial reads fail
        read("i", useg_4K_p0_evaddr, 0, {29{1'bx}});
        read("d", useg_4M_p1_ovaddr, 0, {29{1'bx}});
        read("a", useg_256M_g_evaddr, 0, {29{1'bx}});
        tlbp(useg_4K_p0_evaddr, {4{1'bx}}, 1'b0);
        tlbp(useg_4M_p1_evaddr, {4{1'bx}}, 1'b0);
        tlbp(useg_4K_g_ovaddr, {4{1'bx}}, 1'b0);

        // Tlbr/Tlbw (Write->Read TLB)
        tlbw(4'd1, useg_4K_p0_entry);
        tlbr(4'd1, useg_4K_p0_entry_exp);
        tlbw(4'd2, useg_4M_p1_entry);
        tlbr(4'd2, useg_4M_p1_entry_exp);
        tlbw(4'd3, useg_4K_g_entry);
        tlbr(4'd3, useg_4K_g_entry_exp);
        tlbw(4'd4, useg_256M_g_entry);
        tlbr(4'd4, useg_256M_g_entry_exp);

        // Tlbp (Probe)
        tlbp(useg_4K_p0_evaddr,  4'd1, 1'b1);
        tlbp(useg_4K_p0_ovaddr,  4'd1, 1'b1);
        tlbp(useg_4M_p1_evaddr,  4'd2, 1'b1);
        tlbp(useg_4K_g_ovaddr,   4'd3, 1'b1);
        tlbp(useg_4K_g_evaddr,   4'd3, 1'b1);
        tlbp(useg_256M_g_evaddr, 4'd4, 1'b1);
        tlbp(useg_256M_g_ovaddr, 4'd4, 1'b1);

        // Mapped memory accesses
        read("i", useg_4K_p0_evaddr, 1, useg_4K_p0_epaddr);
        read("i", useg_4K_p0_ovaddr, 1, useg_4K_p0_opaddr);
        read("i", useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr);
        read("i", useg_4M_p1_ovaddr, 1, useg_4M_p1_opaddr);
        read("i", useg_4K_g_evaddr, 1, useg_4K_g_epaddr);
        read("i", useg_4K_g_ovaddr, 1, useg_4K_g_opaddr);
        read("i", useg_4K_p0_m1vaddr, 0, {29{1'bx}});
        read("i", useg_4K_p0_m2vaddr, 0, {29{1'bx}});
        read("i", useg_256M_g_evaddr, 1, useg_256M_g_epaddr);
        read("i", useg_256M_g_ovaddr, 1, useg_256M_g_opaddr);
        read("d", useg_4K_p0_evaddr, 1, useg_4K_p0_epaddr);
        read("d", useg_4K_p0_ovaddr, 1, useg_4K_p0_opaddr);
        read("d", useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr);
        read("d", useg_4M_p1_ovaddr, 1, useg_4M_p1_opaddr);
        read("d", useg_4K_g_evaddr, 1, useg_4K_g_epaddr);
        read("d", useg_4K_g_ovaddr, 1, useg_4K_g_opaddr);
        read("d", useg_4K_p0_m1vaddr, 0, {29{1'bx}});
        read("d", useg_4K_p0_m2vaddr, 0, {29{1'bx}});
        read("d", useg_256M_g_evaddr, 1, useg_256M_g_epaddr);
        read("d", useg_256M_g_evaddr, 1, useg_256M_g_epaddr);

        // Unmapped memory accesses: kuseg conditional, kseg{0,1} always
        // Uncached memory accesses: kuseg conditional, kseg0 conditional, kseg1 always
        read("a", kseg1_vaddr1, 1, {kseg1_paddr1, 3'b010, 1'b1, 1'b1});
        read("a", kseg1_vaddr2, 1, {kseg1_paddr2, 3'b010, 1'b1, 1'b1});
        Kseg0_C = 3'b001;
        cycle();
        read("a", kseg0_vaddr1, 1, {kseg0_paddr1, 3'b001, 1'b1, 1'b1});
        read("a", kseg0_vaddr2, 1, {kseg0_paddr2, 3'b001, 1'b1, 1'b1});
        Kseg0_C = 3'b010;
        cycle();
        read("a", kseg0_vaddr1, 1, {kseg0_paddr1, 3'b010, 1'b1, 1'b1});
        read("a", kseg0_vaddr2, 1, {kseg0_paddr2, 3'b010, 1'b1, 1'b1});
        Kseg0_C = 3'b111;
        cycle();
        read("a", kseg0_vaddr1, 1, {kseg0_paddr1, 3'b111, 1'b1, 1'b1});
        read("a", kseg0_vaddr2, 1, {kseg0_paddr2, 3'b111, 1'b1, 1'b1});
        Useg_MC = 0;
        cycle();
        read("a", useg_4K_p0_ovaddr, 1, {4'b0000, useg_4K_p0_ovaddr[27:8], 3'b010, 1'b1, 1'b1});
        read("a", useg_4K_p0_m1vaddr, 1, {4'b0000, useg_4K_p0_m1vaddr[27:8], 3'b010, 1'b1, 1'b1});
        read("a", useg_4M_p1_evaddr, 1, {4'b0000, useg_4M_p1_evaddr[27:8], 3'b010, 1'b1, 1'b1});
        read("a", kseg0_vaddr1, 1, {kseg0_paddr1, 3'b111, 1'b1, 1'b1});
        read("a", kseg0_vaddr2, 1, {kseg0_paddr2, 3'b111, 1'b1, 1'b1});
        Useg_MC = 1;
        cycle();

        // Pipelined read
        read_pipe("a", useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr, useg_4K_p0_ovaddr, 1, useg_4K_p0_opaddr);   // hit->hit, even->odd, 4M->4K
        read_pipe("a", useg_4K_g_evaddr, 1, useg_4K_g_epaddr, useg_4K_p0_m1vaddr, 0, {28{1'bx}});           // hit->miss
        read_pipe("a", useg_4M_p1_ovaddr, 1, useg_4M_p1_opaddr, useg_4K_p0_evaddr, 1, useg_4K_p0_epaddr);   // hit->hit, odd->even, 4K->4M
        read_pipe("a", useg_4K_p0_m1vaddr, 0, {28{1'bx}}, useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr);         // miss->hit
        read_pipe("a", useg_4K_p0_m1vaddr, 0, {28{1'bx}}, useg_4K_p0_m2vaddr, 0, {28{1'bx}});               // miss->miss
        read_pipe("a", kseg1_vaddr1, 1, {kseg1_paddr1, 3'b010, 1'b1, 1'b1}, kseg1_vaddr2, 1, {kseg1_paddr2, 3'b010, 1'b1, 1'b1});   // hit->hit

        // Pipelined read with stalls
        read_pipe_stall("a", useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr, useg_4K_p0_ovaddr, 1, useg_4K_p0_opaddr);
        read_pipe_stall("a", useg_4K_g_evaddr, 1, useg_4K_g_epaddr, useg_4K_p0_m1vaddr, 0, {28{1'bx}});
        read_pipe_stall("a", useg_4M_p1_ovaddr, 1, useg_4M_p1_opaddr, useg_4K_p0_evaddr, 1, useg_4K_p0_epaddr);
        read_pipe_stall("a", useg_4K_p0_m1vaddr, 0, {28{1'bx}}, useg_4M_p1_evaddr, 1, useg_4M_p1_epaddr);
        read_pipe_stall("a", useg_4K_p0_m1vaddr, 0, {28{1'bx}}, useg_4K_p0_m2vaddr, 0, {28{1'bx}});
        read_pipe_stall("a", kseg1_vaddr1, 1, {kseg1_paddr1, 3'b010, 1'b1, 1'b1}, kseg1_vaddr2, 1, {kseg1_paddr2, 3'b010, 1'b1, 1'b1});

        // TODO: Add tests where 2nd-cycle (service stage) stalls and request data changes. Test with unmapped/mapped.

        // Success
        $fwrite(res, "1");
        $fclose(res);
        @(posedge clock);
        $finish;
    end

    // Task read single request
    task read;
    input [7:0] port;   // 'i', 'd', or 'a' for both
    input [27:0] addr_in;
    input exp_hit;
    input [28:0] exp_data;
    begin
        @(posedge clock) begin
            VPN_I  <= addr_in[27:8];
            VPN_D  <= addr_in[27:8];
            ASID_I <= addr_in[7:0];
            ASID_D <= addr_in[7:0];
        end
        @(posedge clock);
        check_cur(port, exp_hit, exp_data);
    end
    endtask

    // Task read pipelined
    task read_pipe;
    input [7:0] port;   // 'i', 'd', or 'a' for both
    input [27:0] addr1_in;
    input exp_hit1;
    input [28:0] exp_data1;
    input [27:0] addr2_in;
    input exp_hit2;
    input [28:0] exp_data2;
    begin
        @(posedge clock) begin
            VPN_I  <= addr1_in[27:8];
            VPN_D  <= addr1_in[27:8];
            ASID_I <= addr1_in[7:0];
            ASID_D <= addr1_in[7:0];
        end
        @(posedge clock) begin
            VPN_I  <= addr2_in[27:8];
            VPN_D  <= addr2_in[27:8];
            ASID_I <= addr2_in[7:0];
            ASID_D <= addr2_in[7:0];
        end
        check_cur(port, exp_hit1, exp_data1);
        @(posedge clock);
        check_cur(port, exp_hit2, exp_data2);
    end
    endtask

    // Task read pipelined with stalling
    task read_pipe_stall;
    input [7:0] port;   // 'i', 'd', or 'a' for both
    input [27:0] addr1_in;
    input exp_hit1;
    input [28:0] exp_data1;
    input [27:0] addr2_in;
    input exp_hit2;
    input [28:0] exp_data2;
    begin
        @(posedge clock) begin
            VPN_I  <= addr1_in[27:8];
            VPN_D  <= addr1_in[27:8];
            ASID_I <= addr1_in[7:0];
            ASID_D <= addr1_in[7:0];
        end
        @(posedge clock) begin
            Stall_I <= 1;
            Stall_D <= 1;
            VPN_I   <= addr2_in[27:8];
            VPN_D   <= addr2_in[27:8];
            ASID_I  <= addr2_in[7:0];
            ASID_D  <= addr2_in[7:0];
        end
        check_cur(port, exp_hit1, exp_data1);
        cycle();
        cycle();
        check_cur(port, exp_hit1, exp_data1);
        @(posedge clock) begin
            Stall_I <= 0;
            Stall_D <= 0;
        end
        @(posedge clock) begin
            Stall_I <= 1;
            Stall_D <= 1;
        end
        check_cur(port, exp_hit2, exp_data2);
        cycle();
        cycle();
        @(posedge clock) begin
            Stall_I <= 0;
            Stall_D <= 0;
        end
        check_cur(port, exp_hit2, exp_data2);
    end
    endtask

    // Subtask check current output port values
    task check_cur;
    input [7:0] port;   // 'i', 'd', or 'a' for both
    input exp_hit;
    input [28:0] exp_data;
    begin
        @(negedge clock);
        if ((port == "i") | (port == "a")) begin
            if (Hit_I != exp_hit) begin
                $display("Fail: Hit_I: %b (%b expected).", Hit_I, exp_hit);
                fail();
            end
            if (PFN_I != exp_data[28:5]) begin
                $display("Fail: PFN_I: %h (%h expected).", PFN_I, exp_data[28:5]);
                fail();
            end
            if (Cache_I != exp_data[4:2]) begin
                $display("Fail: Cache_I: %h (%h expected).", Cache_I, exp_data[4:2]);
                fail();
            end
            if (Dirty_I != exp_data[1]) begin
                $display("Fail: Dirty_I: %b (%b expected).", Dirty_I, exp_data[1]);
                fail();
            end
            if (Valid_I != exp_data[0]) begin
                $display("Fail: Valid_I: %b (%b expected).", Valid_I, exp_data[0]);
                fail();
            end
        end
        if ((port == "d") | (port == "a")) begin
            if (Hit_D != exp_hit) begin
                $display("Fail: Hit_D: %b (%b expected).", Hit_D, exp_hit);
                fail();
            end
            if (PFN_D != exp_data[28:5]) begin
                $display("Fail: PFN_D: %h (%h expected).", PFN_D, exp_data[28:5]);
                fail();
            end
            if (Cache_D != exp_data[4:2]) begin
                $display("Fail: Cache_D: %h (%h expected).", Cache_D, exp_data[4:2]);
                fail();
            end
            if (Dirty_D != exp_data[1]) begin
                $display("Fail: Dirty_D: %b (%b expected).", Dirty_D, exp_data[1]);
                fail();
            end
            if (Valid_D != exp_data[0]) begin
                $display("Fail: Valid_D: %b (%b expected).", Valid_D, exp_data[0]);
                fail();
            end
        end
        if ((port != "i") & (port != "d") & (port != "a")) begin
            $display("Fail: check_cur invalid port selection 0x%h", port);
            fail();
        end
    end
    endtask

    // Task probe
    task tlbp;
    input [27:0] addr_in;
    input [3:0] exp_index;
    input exp_hit;
    begin
        @(posedge clock) begin
            VPN_D  <= addr_in[27:8];
            ASID_D <= addr_in[7:0];
        end
        @(posedge clock);
        @(negedge clock);
        if (Hit_D != exp_hit) begin
            $display("Fail: Hit_D: %b (%b expected).", Hit_D, exp_hit);
            fail();
        end
        if (Index_Out != exp_index) begin
            $display("Fail: Index_Out: %h (%h expected).", Index_Out, exp_index);
            fail();
        end
    end
    endtask

    // Task TLB write
    task tlbw;
    input [3:0] idx_in;
    input [101:0] data_in;
    begin
        @(posedge clock) begin
            Index_In <= idx_in;
            VPN2_In  <= data_in[101:83];
            Mask_In  <= data_in[82:67];
            ASID_In  <= data_in[66:59];
            G_In     <= data_in[58];
            PFN0_In  <= data_in[57:34];
            C0_In    <= data_in[33:31];
            D0_In    <= data_in[30];
            V0_In    <= data_in[29];
            PFN1_In  <= data_in[28:5];
            C1_In    <= data_in[4:2];
            D1_In    <= data_in[1];
            V1_In    <= data_in[0];
            Write    <= 1;
        end
        @(posedge clock) begin
            Write    <= 0;
        end
    end
    endtask

    // Task TLB read
    task tlbr;
    input [3:0] idx_in;
    input [101:0] exp_data;
    begin
        @(posedge clock) begin
            Read <= 1;
        end
        @(posedge clock) begin
            Read <= 0;
        end
        @(negedge clock);
        if (VPN2_Out != exp_data[101:83]) begin
            $display("Fail: VPN2_Out: %h (%h expected).", VPN2_Out, exp_data[101:83]);
            fail();
        end
        if (Mask_Out != exp_data[82:67]) begin
            $display("Fail: Mask_Out: %h (%h expected).", Mask_Out , exp_data[82:67]);
            fail();
        end
        if (ASID_Out != exp_data[66:59]) begin
            $display("Fail: ASID_Out: %h (%h expected).", ASID_Out, exp_data[66:59]);
            fail();
        end
        if (G_Out != exp_data[58]) begin
            $display("Fail: G_Out: %b (%b expected).", G_Out, exp_data[58]);
            fail();
        end
        if (PFN0_Out != exp_data[57:34]) begin
            $display("Fail: PFN0_Out: %h (%h expected).", PFN0_Out, exp_data[57:34]);
            fail();
        end
        if (C0_Out != exp_data[33:31]) begin
            $display("Fail: C0_Out: %h (%h expected).", C0_Out, exp_data[33:31]);
            fail();
        end
        if (D0_Out != exp_data[30]) begin
            $display("Fail: D0_Out: %b (%b expected).", D0_Out, exp_data[30]);
            fail();
        end
        if (V0_Out != exp_data[29]) begin
            $display("Fail: V0_Out: %b (%b expected).", V0_Out, exp_data[29]);
            fail();
        end
        if (PFN1_Out != exp_data[28:5]) begin
            $display("Fail: PFN1_Out: %h (%h expected).", PFN1_Out, exp_data[28:5]);
            fail();
        end
        if (C1_Out != exp_data[4:2]) begin
            $display("Fail: C1_Out: %h (%h expected).", C1_Out, exp_data[4:2]);
            fail();
        end
        if (D1_Out != exp_data[1]) begin
            $display("Fail: D1_Out: %b (%b expected).", D1_Out, exp_data[1]);
            fail();
        end
        if (V1_Out != exp_data[0]) begin
            $display("Fail: V1_Out: %b (%b expected).", V1_Out, exp_data[0]);
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

