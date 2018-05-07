`timescale 1ns / 1ps
/*
 * File         : InstructionCache_8KB_test.v
 * Project      : MIPS32 MUX
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Test module.
 */
module InstructionCache_8KB_test;

    localparam PABITS = 36; // Test only handles '36'

    // Inputs
    reg clock;
    reg reset;
    reg [9:0] VAddressIn_C;
    reg [23:0] PAddressIn_C;
    reg PAddressValid_C;
    reg [2:0] CacheAttr_C;
    reg Stall_C;
    reg Read_C;
    reg DoCacheOp_C;
    reg [2:0] CacheOp_C;
    reg [25:0] CacheOpData_C;
    wire [31:0] DataIn_M;
    wire [1:0] DataInOffset_M;
    wire Ready_M;

    // Outputs
    wire [31:0] DataOut_C;
    wire Ready_C;
    wire Blocked_C;
    wire [33:0] Address_M;
    wire ReadLine_M;
    wire ReadWord_M;

    // Signals for loading memory
    reg [17:0] MemWrite_Address;
    reg MemWrite_Enable;
    reg [31:0] MemWrite_WordIn;
    wire MemWrite_Ready;

    // Instantiate the Unit Under Test (UUT)
    InstructionCache_8KB #(.PABITS(PABITS)) uut (
        .clock            (clock),
        .reset            (reset),
        .VAddressIn_C     (VAddressIn_C),
        .PAddressIn_C     (PAddressIn_C),
        .PAddressValid_C  (PAddressValid_C),
        .CacheAttr_C      (CacheAttr_C),
        .Stall_C          (Stall_C),
        .Read_C           (Read_C),
        .DataOut_C        (DataOut_C),
        .Ready_C          (Ready_C),
        .Blocked_C        (Blocked_C),
        .DoCacheOp_C      (DoCacheOp_C),
        .CacheOp_C        (CacheOp_C),
        .CacheOpData_C    (CacheOpData_C),
        .Address_M        (Address_M),
        .ReadLine_M       (ReadLine_M),
        .ReadWord_M       (ReadWord_M),
        .DataIn_M         (DataIn_M),
        .DataInOffset_M   (DataInOffset_M),
        .Ready_M          (Ready_M)
    );

    // Instantiate the Memory Module (1 MB: Keep lower 16 bits different)
    MainMemory #(.ADDR_WIDTH(16)) mem (
        .clock            (clock),
        .reset            (reset),
        .I_Address        (Address_M[17:0]),
        .I_DataIn         ({128{1'b0}}),
        .I_DataOut        (DataIn_M),
        .I_Ready          (Ready_M),
        .I_DataOutOffset  (DataInOffset_M),
        .I_BootWrite      (1'b0),
        .I_ReadLine       (ReadLine_M),
        .I_ReadWord       (ReadWord_M),
        .D_Address        (MemWrite_Address),
        .D_DataIn         ({{96{1'b0}},MemWrite_WordIn}),
        .D_LineInReady    (1'b0),
        .D_WordInReady    (MemWrite_Enable),
        .D_WordInBE       (4'hf),
        .D_DataOut        (),
        .D_DataOutOffset  (),
        .D_ReadLine       (1'b0),
        .D_ReadWord       (1'b0),
        .D_Ready          (MemWrite_Ready)
    );
    integer res;
    integer i, j;

    // Task parameters
    localparam [0:0] cache = 1'b1;          // Set address cacheable
    localparam [0:0] nocache = 1'b0;        // Set address non-cacheable
    localparam [0:0] valid = 1'b1;          // Set address valid (i.e., TLB hit)
    localparam [0:0] invalid = 1'b0;        // Set address invalid (i.e., TLB miss)
    localparam [0:0] hit = 1'b1;            // Expect a hit
    localparam [0:0] miss = 1'b0;           // Expect a miss

    // 10-bit virtual/physical offsets
    localparam [9:0]  VAddr0w0 = 10'h3a8;   // Line 0 Word 0 (idx 234)
    localparam [9:0]  VAddr0w1 = 10'h3a9;   // Line 0 Word 1
    localparam [9:0]  VAddr0w2 = 10'h3aa;   // Line 0 Word 2
    localparam [9:0]  VAddr0w3 = 10'h3ab;   // Line 0 Word 3
    localparam [9:0]  VAddr1w0 = 10'h3a8;   // Line 1 Word 0 (idx 234)
    localparam [9:0]  VAddr1w1 = 10'h3a9;   // Line 1 Word 1
    localparam [9:0]  VAddr1w2 = 10'h3aa;   // Line 1 Word 2
    localparam [9:0]  VAddr1w3 = 10'h3ab;   // Line 1 Word 3
    localparam [9:0]  VAddr2w0 = 10'h330;   // Line 2 Word 0 (idx 204)
    localparam [9:0]  VAddr2w1 = 10'h331;   // Line 2 Word 1
    localparam [9:0]  VAddr2w2 = 10'h332;   // Line 2 Word 2
    localparam [9:0]  VAddr2w3 = 10'h333;   // Line 2 Word 3

    // 24-bit physical tags
    localparam [23:0] PTag0 = 24'h314159;   // 0011_0001_0100_0001_0101_1001
    localparam [23:0] PTag1 = 24'hdeaf76;   // 1101_1110_1010_1111_0111_0110
    localparam [23:0] PTag2 = 24'h555557;   // 0101_0101_0101_0101_0101_0111

    // 32-bit line addresses (16-byte block size)
    localparam [31:0] MLineAddr0 = {PTag0, VAddr0w0[9:2]};
    localparam [31:0] MLineAddr1 = {PTag1, VAddr1w0[9:2]};
    localparam [31:0] MLineAddr2 = {PTag2, VAddr2w0[9:2]};

    // 34-bit word addresses (4-byte block size)
    localparam [33:0] MLineAddr0w0 = {PTag0, VAddr0w0};
    localparam [33:0] MLineAddr0w1 = {PTag0, VAddr0w1};
    localparam [33:0] MLineAddr0w2 = {PTag0, VAddr0w2};
    localparam [33:0] MLineAddr0w3 = {PTag0, VAddr0w3};
    localparam [33:0] MLineAddr1w0 = {PTag1, VAddr1w0};
    localparam [33:0] MLineAddr1w1 = {PTag1, VAddr1w1};
    localparam [33:0] MLineAddr1w2 = {PTag1, VAddr1w2};
    localparam [33:0] MLineAddr1w3 = {PTag1, VAddr1w3};
    localparam [33:0] MLineAddr2w0 = {PTag2, VAddr2w0};
    localparam [33:0] MLineAddr2w1 = {PTag2, VAddr2w1};
    localparam [33:0] MLineAddr2w2 = {PTag2, VAddr2w2};
    localparam [33:0] MLineAddr2w3 = {PTag2, VAddr2w3};

    // Data
    localparam [31:0] MLine0Word0 = 32'hf39acd22;
    localparam [31:0] MLine0Word1 = 32'haaabbbcc;
    localparam [31:0] MLine0Word2 = 32'hddf80c25;
    localparam [31:0] MLine0Word3 = 32'hff00ff00;
    localparam [31:0] MLine1Word0 = 32'h00012345;
    localparam [31:0] MLine1Word1 = 32'h77000777;
    localparam [31:0] MLine1Word2 = 32'h83cf0001;
    localparam [31:0] MLine1Word3 = 32'h050f030e;
    localparam [31:0] MLine2Word0 = 32'habc00112;
    localparam [31:0] MLine2Word1 = 32'hdef11223;
    localparam [31:0] MLine2Word2 = 32'h71717171;
    localparam [31:0] MLine2Word3 = 32'h33443344;

    initial begin
        // Initialize Inputs
        clock = 0;
        reset = 0;
        VAddressIn_C = 0;
        PAddressIn_C = 0;
        PAddressValid_C = 0;
        CacheAttr_C = 0;
        Stall_C = 0;
        Read_C = 0;
        DoCacheOp_C = 0;
        CacheOp_C = 0;
        CacheOpData_C = 0;

        // Wait 100 ns for global reset to finish
        #100;

        // Add stimulus here
        res = $fopen("result.out");
        do_reset();
        cache_reset();

        // Load initial memory contents
        load_memory(MLineAddr0w0, MLine0Word0);
        load_memory(MLineAddr0w1, MLine0Word1);
        load_memory(MLineAddr0w2, MLine0Word2);
        load_memory(MLineAddr0w3, MLine0Word3);
        load_memory(MLineAddr1w0, MLine1Word0);
        load_memory(MLineAddr1w1, MLine1Word1);
        load_memory(MLineAddr1w2, MLine1Word2);
        load_memory(MLineAddr1w3, MLine1Word3);
        load_memory(MLineAddr2w0, MLine2Word0);
        load_memory(MLineAddr2w1, MLine2Word1);
        load_memory(MLineAddr2w2, MLine2Word2);
        load_memory(MLineAddr2w3, MLine2Word3);

        // Basic read test
        read(VAddr0w0, PTag0, cache, valid, miss, MLine0Word0);
        read(VAddr0w1, PTag0, cache, valid, hit, MLine0Word1);
        read(VAddr0w2, PTag0, cache, valid, hit, MLine0Word2);
        read(VAddr0w3, PTag0, cache, valid, hit, MLine0Word3);

        read(VAddr2w3, PTag2, cache, valid, miss, MLine2Word3);
        read(VAddr2w1, PTag2, cache, valid, hit, MLine2Word1);
        read(VAddr2w0, PTag2, cache, valid, hit, MLine2Word0);
        read(VAddr2w2, PTag2, cache, valid, hit, MLine2Word2);

        // Read to same index; both should hit
        read(VAddr1w0, PTag1, cache, valid, miss, MLine1Word0);
        read(VAddr1w1, PTag1, cache, valid, hit, MLine1Word1);
        read(VAddr1w2, PTag1, cache, valid, hit, MLine1Word2);
        read(VAddr1w3, PTag1, cache, valid, hit, MLine1Word3);
        read(VAddr0w3, PTag0, cache, valid, hit, MLine0Word3);
        read(VAddr0w2, PTag0, cache, valid, hit, MLine0Word2);
        read(VAddr0w1, PTag0, cache, valid, hit, MLine0Word1);
        read(VAddr0w0, PTag0, cache, valid, hit, MLine0Word0);

        // Check LRU: Oldest should evict
        read(VAddr0w0, PTag2, cache, valid, miss, {32{1'bx}});
        read(VAddr1w0, PTag1, cache, valid, miss, MLine1Word0);
        read(VAddr0w0, PTag0, cache, valid, miss, MLine0Word0);

        // Read pipelined (hit)
        read_pipe(VAddr0w0, PTag0, cache, valid, hit, MLine0Word0, VAddr1w0, PTag1, cache, valid, hit, MLine1Word0);

        // Read uncacheable
        read(VAddr2w0, PTag2, nocache, valid, 1'bx, MLine2Word0);
        cache_reset();
        read(VAddr2w0, PTag2, nocache, valid, 1'bx, MLine2Word0);

        // CacheOp: Store Tag
        cache_idxstag(8'hff, 1'b1, {26{1'b1}}); // Store tag 1s to index 1s
        read({10{1'b1}}, {24{1'b1}}, cache, valid, hit, {32{1'bx}}); // The stored tag should be a hit
        cache_idxstag(8'hff, 1'b1, {{24{1'b1}}, 2'b00}); // now invalid
        read({10{1'b1}}, {24{1'b1}}, cache, valid, miss, {32{1'bx}}); // Miss due to invalidity

        // CacheOp: Index invalidate
        cache_idxstag(8'hff, 1'b0, {13{2'b10}});
        read({10{1'b1}}, {12{2'b10}}, cache, valid, hit, {32{1'bx}});
        cache_idxinv({10{1'b1}}, 1'b0);
        read({10{1'b1}}, {12{2'b10}}, cache, valid, miss, {32{1'bx}});

        // CacheOp: Address hit invalidate
        cache_reset();
        read(VAddr2w2, PTag2, cache, valid, miss, MLine2Word2);
        cache_addrhinv(VAddr2w2, PTag2, valid, hit); // Invalidate a hit
        read(VAddr2w2, PTag2, cache, valid, miss, MLine2Word2);
        cache_addrhinv(VAddr2w2, PTag1, valid, miss);  // Do not invalidate a miss
        read(VAddr2w2, PTag2, cache, valid, hit, MLine2Word2);

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
    end

    // Load memory with one data word
    task load_memory;
    input [16:0] address;
    input [31:0] data;
    begin
        @(posedge clock) begin
            MemWrite_Address <= address;
            MemWrite_WordIn <= data;
            MemWrite_Enable <= 1'b1;
        end
        i = 0;
        while (~MemWrite_Ready & (i != 10000)) begin
            cycle();
            i = i + 1;
        end
        MemWrite_Enable <= 1'b0;
        cycle();
        if (i == 10000) begin
            $display("Fail: Memory write timeout");
            fail();
        end
    end
    endtask

    // Task cache reset (index store tag 0s for all indices
    task cache_reset;
    begin
        for (j = 0; j < 256; j = j + 1) begin
            cache_idxstag(j[7:0], 1'b0, {26{1'b0}});
            cache_idxstag(j[7:0], 1'b1, {26{1'b0}});
        end
    end
    endtask

    // Task cache address hit invalidate (no verification)
    task cache_addrhinv;
    input [9:0] vaddr_in;
    input [23:0] paddr_in;
    input valid_in;
    input exp_hit;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in;
            CacheOp_C <= 3'b100; // CacheOpI_Adr_HInv
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr_in;
            PAddressValid_C <= valid_in;
            CacheAttr_C <= 3'b111;
            DoCacheOp_C <= 1'b0;
        end
        check_hit(exp_hit);
    end
    endtask


    // Task cache index invalidate (no verification)
    task cache_idxinv;
    input [7:0] idx_in;
    input setAsel_in;
    begin
        @(posedge clock) begin
            VAddressIn_C <= {idx_in, 2'b00};
            CacheOp_C <= 3'b000; // CacheOpI_Idx_Inv
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= {{23{1'b0}}, setAsel_in};
            DoCacheOp_C <= 1'b0;
        end
    end
    endtask

    // Task cache index store tag (no verification)
    task cache_idxstag;
    input [7:0] idx_in;
    input setAsel_in;
    input [25:0] data_in;
    begin
        @(posedge clock) begin
            VAddressIn_C <= {idx_in, 2'b00};
            CacheOpData_C <= data_in;
            CacheOp_C <= 3'b010; // CacheOpI_Idx_STag
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= {{23{1'b0}}, setAsel_in};
            PAddressValid_C <= 1'b1;
            DoCacheOp_C <= 1'b0;
        end
        wait_ready();
    end
    endtask;

    // Task read
    task read;
    input [9:0] vaddr_in;
    input [23:0] paddr_in;
    input cache_in;         // cacheable or not (1/0)
    input valid_in;         // paddress is valid
    input exp_hitmiss;      // expected hit or miss
    input [31:0] exp_data;  // expected output data
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in;
            Read_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr_in;
            PAddressValid_C <= valid_in;
            CacheAttr_C <= {1'b0, ~cache_in, 1'b0}; // 3'b010 is uncacheable
            VAddressIn_C <= 10'h0;  // arbitrary
            Read_C <= 1'b0;
        end
        check_hit(exp_hitmiss);
        wait_ready();
        check_data(exp_data);
    end
    endtask

    // Task read pipelined
    task read_pipe;
    input [9:0] vaddr1_in;
    input [23:0] paddr1_in;
    input cache1_in;
    input valid1_in;
    input exp_hitmiss1;
    input [31:0] exp_data1;
    input [9:0] vaddr2_in;
    input [23:0] paddr2_in;
    input cache2_in;
    input valid2_in;
    input exp_hitmiss2;
    input [31:0] exp_data2;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr1_in;
            Read_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr1_in;
            PAddressValid_C <= valid1_in;
            CacheAttr_C <= {1'b0, ~cache1_in, 1'b0};
            VAddressIn_C <= vaddr2_in;
        end
        check_hit(exp_hitmiss1);
        wait_ready();
        check_data(exp_data1);
        @(posedge clock) begin
            PAddressIn_C <= paddr2_in;
            PAddressValid_C <= valid2_in;
            CacheAttr_C <= {1'b0, ~cache2_in, 1'b0};
            VAddressIn_C <= 10'h0;  // arbitrary
            Read_C <= 1'b0;
        end
        check_hit(exp_hitmiss2);
        wait_ready();
        check_data(exp_data2);
    end
    endtask

    // Task check hit
    task check_hit;
    input exp_hit;
    begin
        @(negedge clock);
        if (uut.hit_any != exp_hit) begin
            $display("Fail: hit_any: %b (%b expected).", uut.hit_any, exp_hit);
            fail();
        end
    end
    endtask

    // Task check data
    task check_data;
    input [31:0] exp_data;
    begin
        // Don't fail if the expected value is all Xs
        if ((exp_data !== {32{1'bx}}) && (DataOut_C !== exp_data)) begin
            $display("Fail: DataOut_C: %h (%h expected).", DataOut_C, exp_data);
            fail();
        end
    end
    endtask

    // Task wait for Ready_C (up to 10,000 cycles)
    task wait_ready;
    begin
        i = 0;
        while (~Ready_C & (i != 10000)) begin
            cycle();
            i = i + 1;
        end
        if (i == 10000) begin
            $display("Fail: Wait timeout");
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

    // Always run the clock (100MHz)
    initial forever begin
        #5 clock <= ~clock;
    end

endmodule

