`timescale 1ns / 1ps
/*
 * File         : DataCache_2KB_test.v
 * Project      : MIPS32 MUX
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   Test module.
 */
module DataCache_2KB_test;

    /* 2KB Cache Note:
     * There are only 6 index bits which only covers bits [9:0] of the virtual address.
     * Thus the highest two offset bits ([11:10]) are part of the tag.
     */

    localparam PABITS = 36; // Test only handles '36'

    // Inputs
    reg clock;
    reg reset;
    reg [9:0] VAddressIn_C;
    reg [23:0] PAddressIn_C;
    reg PAddressValid_C;
    reg [2:0] CacheAttr_C;
    reg Stall_C;
    reg [31:0] DataIn_C;
    reg Read_C;
    reg [3:0] Write_C;
    reg DoCacheOp_C;
    reg [2:0] CacheOp_C;
    reg [27:0] CacheOpData_C;
    wire [31:0] DataIn_M;
    wire [1:0] DataInOffset_M;
    wire Ready_M;

    // Outputs
    wire [31:0] DataOut_C;
    wire Ready_C;
    wire [33:0] Address_M;
    wire ReadLine_M;
    wire ReadWord_M;
    wire LineOutReady_M;
    wire WordOutReady_M;
    wire [3:0] WordOutBE_M;
    wire [127:0] DataOut_M;

    // Instantiate the Unit Under Test (UUT)
    DataCache_2KB #(.PABITS(PABITS)) uut (
        .clock            (clock),
        .reset            (reset),
        .VAddressIn_C     (VAddressIn_C),
        .PAddressIn_C     (PAddressIn_C),
        .PAddressValid_C  (PAddressValid_C),
        .CacheAttr_C      (CacheAttr_C),
        .Stall_C          (Stall_C),
        .DataIn_C         (DataIn_C),
        .Read_C           (Read_C),
        .Write_C          (Write_C),
        .DataOut_C        (DataOut_C),
        .Ready_C          (Ready_C),
        .DoCacheOp_C      (DoCacheOp_C),
        .CacheOp_C        (CacheOp_C),
        .CacheOpData_C    (CacheOpData_C),
        .Address_M        (Address_M),
        .ReadLine_M       (ReadLine_M),
        .ReadWord_M       (ReadWord_M),
        .DataIn_M         (DataIn_M),
        .DataInOffset_M   (DataInOffset_M),
        .LineOutReady_M   (LineOutReady_M),
        .WordOutReady_M   (WordOutReady_M),
        .WordOutBE_M      (WordOutBE_M),
        .DataOut_M        (DataOut_M),
        .Ready_M          (Ready_M)
    );

    // Instantiate the Memory Module (1 MB: Keep lower 16 bits different)
    MainMemory #(.ADDR_WIDTH(16)) mem (
        .clock            (clock),
        .reset            (reset),
        .I_Address        ({18{1'b0}}),
        .I_DataIn         ({128{1'b0}}),
        .I_DataOut        (),
        .I_Ready          (),
        .I_DataOutOffset  (),
        .I_BootWrite      (1'b0),
        .I_ReadLine       (1'b0),
        .I_ReadWord       (1'b0),
        .D_Address        (Address_M[17:0]),
        .D_DataIn         (DataOut_M),
        .D_LineInReady    (LineOutReady_M),
        .D_WordInReady    (WordOutReady_M),
        .D_WordInBE       (WordOutBE_M),
        .D_DataOut        (DataIn_M),
        .D_DataOutOffset  (DataInOffset_M),
        .D_ReadLine       (ReadLine_M),
        .D_ReadWord       (ReadWord_M),
        .D_Ready          (Ready_M)
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

    // 24-bit physical tags
    localparam [23:0] PTag0 = 24'habcdef;   // 1010_1011_1100_1101_1110_1111
    localparam [23:0] PTag1 = 24'h787878;   // 0111_1000_0111_1000_0111_1000
    localparam [23:0] PTag2 = 24'h37f2a5;   // 0011_0111_1111_0010_1010_0101

    // 12-bit virtual/physical offsets
    localparam [11:0] VAddr0w0 = 12'hab0;   // Line 0 Word 0    (Index 43)
    localparam [11:0] VAddr0w1 = 12'hab4;   // Line 0 Word 1
    localparam [11:0] VAddr0w2 = 12'hab8;   // Line 0 Word 2
    localparam [11:0] VAddr0w3 = 12'habc;   // Line 0 Word 3
    localparam [11:0] VAddr1w0 = 12'h000;   // Line 1 Word 0    (Index 0)
    localparam [11:0] VAddr1w1 = 12'h004;   // Line 1 Word 1
    localparam [11:0] VAddr1w2 = 12'h008;   // Line 1 Word 2
    localparam [11:0] VAddr1w3 = 12'h00c;   // Line 1 Word 3

    // Data
    localparam [31:0] Data0w0 = 32'haaabbbcc;
    localparam [31:0] Data0w1 = 32'h98765432;
    localparam [31:0] Data0w2 = 32'h11223344;
    localparam [31:0] Data0w3 = 32'habcdedcb;
    localparam [31:0] Data1w0 = 32'h77abc77d;
    localparam [31:0] Data1w1 = 32'h10000001;
    localparam [31:0] Data1w2 = 32'h00030000;
    localparam [31:0] Data1w3 = 32'hffffffff;
    localparam [31:0] Data2w0 = 32'h44444444;
    localparam [31:0] Data2w1 = 32'h55555555;
    localparam [31:0] Data2w2 = 32'h66666666;
    localparam [31:0] Data2w3 = 32'h77777777;
    localparam [31:0] BadData = 32'hdeafbeef;

    initial begin
        // Initialize Inputs
        clock = 0;
        reset = 0;
        VAddressIn_C = 0;
        PAddressIn_C = 0;
        PAddressValid_C = 0;
        CacheAttr_C = 0;
        Stall_C = 0;
        DataIn_C = 0;
        Read_C = 0;
        Write_C = 0;
        DoCacheOp_C = 0;
        CacheOp_C = 0;
        CacheOpData_C = 0;

        // Wait 100 ns for global reset to finish
        #100;

        // Add stimulus here
        res = $fopen("result.out");
        do_reset();
        cache_reset();


        // This first test checks LRU and writeback addresses
        // Tag 1, Addr 100
        write(12'h400, 24'h000, cache, valid, miss, Data0w0, 4'hf);
        write(12'h404, 24'h000, cache, valid, hit, Data0w1, 4'hf);
        write(12'h408, 24'h000, cache, valid, hit, Data0w2, 4'hf);
        write(12'h40c, 24'h000, cache, valid, hit, Data0w3, 4'hf);

        // Tag 2, Addr 200
        write(12'h800, 24'h000, cache, valid, miss, Data1w0, 4'hf);
        write(12'h804, 24'h000, cache, valid, hit, Data1w1, 4'hf);
        write(12'h808, 24'h000, cache, valid, hit, Data1w2, 4'hf);
        write(12'h80c, 24'h000, cache, valid, hit, Data1w3, 4'hf);

        // Tag 3, Addr 300, Evict Tag 1 Addr 100
        write(12'hc00, 24'h000, cache, valid, miss, Data2w0, 4'hf);
        write(12'hc04, 24'h000, cache, valid, hit, Data2w1, 4'hf);
        write(12'hc08, 24'h000, cache, valid, hit, Data2w2, 4'hf);
        write(12'hc0c, 24'h000, cache, valid, hit, Data2w3, 4'hf);

        // Read Tag 1: Miss, Evict Tag 2
        read (12'h404, 24'h000, cache, valid, miss, Data0w1);
        read (12'h400, 24'h000, cache, valid, hit,  Data0w0);
        // Read Tag 2: Miss, Evict Tag 3
        read (12'h800, 24'h000, cache, valid, miss, Data1w0);
        read (12'h80c, 24'h000, cache, valid, hit,  Data1w3);
        // Read Tag 3: Miss, Evict Tag 2
        read (12'hc08, 24'h000, cache, valid, miss, Data2w2);
        read (12'hc04, 24'h000, cache, valid, hit,  Data2w1);

        cache_reset();

        // Write (miss)
        write(VAddr0w0, PTag0, cache, valid, miss, Data0w0, 4'hf);
        write(VAddr1w3, PTag1, cache, valid, miss, Data1w3, 4'hf);

        // Write (hit)
        write(VAddr0w0, PTag0, cache, valid, hit, Data0w0, 4'hf);
        write(VAddr1w3, PTag1, cache, valid, hit, Data1w3, 4'hf);
        write(VAddr0w1, PTag0, cache, valid, hit, Data0w1, 4'hf);
        write(VAddr1w2, PTag1, cache, valid, hit, Data1w2, 4'hf);
        write(VAddr0w2, PTag0, cache, valid, hit, Data0w2, 4'hf);
        write(VAddr1w1, PTag1, cache, valid, hit, Data1w1, 4'hf);
        write(VAddr0w3, PTag0, cache, valid, hit, Data0w3, 4'hf);
        write(VAddr1w0, PTag1, cache, valid, hit, Data1w0, 4'hf);

        // Write to an index already used by one set
        write(VAddr0w0, PTag1, cache, valid, miss, Data2w0, 4'hf);
        write(VAddr0w1, PTag1, cache, valid, hit,  Data2w1, 4'hf);
        write(VAddr0w2, PTag1, cache, valid, hit,  Data2w2, 4'hf);
        write(VAddr0w3, PTag1, cache, valid, hit,  Data2w3, 4'hf);

        // Expect that both sets are still hits
        read (VAddr0w0, PTag1, cache, valid, hit, Data2w0);
        read (VAddr0w0, PTag0, cache, valid, hit, Data0w0);

        // Write to an index already used by both sets, expect LRU eviction
        write(VAddr0w0, PTag2, cache, valid, miss, Data2w3, 4'hf);
        read (VAddr0w0, PTag0, cache, valid, hit,  Data0w0);
        read (VAddr0w0, PTag1, cache, valid, miss, Data2w0);

        // Read (hit)
        read(VAddr0w0, PTag0, cache, valid, hit, Data0w0);
        read(VAddr1w3, PTag1, cache, valid, hit, Data1w3);
        read(VAddr0w1, PTag0, cache, valid, hit, Data0w1);
        read(VAddr1w2, PTag1, cache, valid, hit, Data1w2);
        read(VAddr0w2, PTag0, cache, valid, hit, Data0w2);
        read(VAddr1w1, PTag1, cache, valid, hit, Data1w1);
        read(VAddr0w3, PTag0, cache, valid, hit, Data0w3);
        read(VAddr1w0, PTag1, cache, valid, hit, Data1w0);

        // Read pipelined (hit)
        read_pipe(VAddr0w0, PTag0, cache, valid, hit, Data0w0, VAddr1w3, PTag1, cache, valid, hit, Data1w3);
        read_pipe(VAddr1w0, PTag1, cache, valid, hit, Data1w0, VAddr1w1, PTag1, cache, valid, hit, Data1w1);

        // Read uncacheable
        write(VAddr0w3, PTag0, nocache, valid, 1'bx, Data0w3, 4'hf);
        read (VAddr0w3, PTag0, nocache, valid, 1'bx, Data0w3);
        write(VAddr1w2, PTag1, nocache, valid, 1'bx, Data1w2, 4'hf);
        read (VAddr1w2, PTag1, nocache, valid, 1'bx, Data1w2);
        read (VAddr1w2, PTag0, nocache, valid, 1'bx, {32{1'bx}});   // Assumes data has not been written (Xs)

        // Write hit (VAddr, PAddr, Cache, Valid, Hit, Data, WBE)
        write(VAddr0w0, PTag0, cache, valid, hit, 32'h00000000, 4'hf);
        read (VAddr0w0, PTag0, cache, valid, hit, 32'h00000000);
        write(VAddr0w0, PTag0, cache, valid, hit, Data0w0, 4'hf);

        // Write hit partial word write
        write(VAddr1w3, PTag1, cache, valid, hit, 32'h00000000, 4'h9);
        read (VAddr1w3, PTag1, cache, valid, hit, {8'h00, Data1w3[23:8], 8'h00});
        write(VAddr1w3, PTag1, cache, valid, hit, Data1w3, 4'hf);

        // CacheOp: Index Store Tag
        cache_reset();
        cache_idxstag(6'h3f, 1'b1, {28{1'b1}}); // Store tag 1s to index 1s
        read ({12{1'b1}}, {24{1'b1}}, cache, valid, hit, {32{1'bx}});    // The stored tag should be a hit
        cache_idxstag(6'h3f, 1'b1, {{26{1'b1}}, 2'b00}); // now invalid
        read({12{1'b1}}, {24{1'b1}}, cache, valid, miss, {32{1'bx}});   // Miss due to invalidity

        // CacheOp: Address Hit Writeback
        cache_reset();
        write(VAddr0w0, PTag0, cache, valid, miss, 32'hdeafbeef, 4'hf);
        write(VAddr0w1, PTag0, cache, valid, hit,  32'h11111111, 4'hf);
        cache_addrhwb(VAddr0w0, PTag0, valid, hit);
        cache_addrhwb(VAddr0w0, PTag1, valid, miss);
        read (VAddr0w0, PTag0, cache, valid, hit, 32'hdeafbeef); // verify no invalidate
        cache_idxstag(6'd43, 1'b0, {28{1'b0}}); // invalidate the line
        cache_idxstag(6'd43, 1'b1, {28{1'b1}});
        read (VAddr0w0, PTag0, cache, valid, miss, 32'hdeafbeef);
        read (VAddr0w1, PTag0, cache, valid, hit,  32'h11111111);
        write(VAddr0w0, PTag0, cache, valid, hit,  32'habcd1234, 4'hf); // don't writeback on a miss
        cache_addrhwb(VAddr0w0, PTag0, invalid, hit);
        cache_idxstag(6'd43, 1'b0, {28{1'b0}});
        cache_idxstag(6'd43, 1'b1, {28{1'b0}});
        read (VAddr0w0, PTag0, cache, valid, miss, 32'hdeafbeef);

        // CacheOp: Address Hit Writeback Invalidate
        cache_reset();
        write(VAddr0w0, PTag0, cache, valid, miss,  32'h22222222, 4'hf);
        write(VAddr0w1, PTag0, cache, valid, hit,  32'h33333333, 4'hf);
        cache_addrhwbinv(VAddr0w0, PTag0, valid, hit);
        cache_addrhwbinv(VAddr0w0, PTag0, valid, miss);
        read (VAddr0w0, PTag0, cache, valid, miss, 32'h22222222); // verify invalidate
        cache_idxstag(6'd43, 1'b0, {28{1'b0}}); // invalidate the line
        cache_idxstag(6'd43, 1'b1, {28{1'b0}});
        read (VAddr0w0, PTag0, cache, valid, miss, 32'h22222222);
        read (VAddr0w1, PTag0, cache, valid, hit,  32'h33333333);
        write(VAddr0w0, PTag0, cache, valid, hit,  32'habcd4321, 4'hf); // don't writeback on a miss
        cache_addrhwbinv(VAddr0w0, PTag0, invalid, hit);
        cache_idxstag(6'd43, 1'b0, {28{1'b0}});
        cache_idxstag(6'd43, 1'b1, {28{1'b0}});
        read (VAddr0w0, PTag0, cache, valid, miss, 32'h22222222);

        // CacheOp: Index Writeback Invalidate
        cache_reset();
        write(VAddr1w0, PTag1, cache, valid, miss, 32'h111, 4'hf);
        write(VAddr1w3, PTag1, cache, valid, hit,  32'h444, 4'hf);
        cache_idxwbinv(6'd0, 1'b0);
        cache_idxwbinv(6'd0, 1'b1);
        read (VAddr1w0, PTag1, cache, valid, miss, 32'h111); // verify invalidate and writeback
        read (VAddr1w3, PTag1, cache, valid, hit,  32'h444);

        // Success
        $fwrite(res, "1");
        $fclose(res);
        $finish;
    end

    // DCache ops: Idx_WbInv, Idx_STag, Adr_HWbInv, Adr_HWb

    // Task cache address hit writeback (no verification)
    task cache_addrhwb;
    input [11:0] vaddr_in;
    input [23:0] paddr_in;
    input valid_in;
    input exp_hit;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in[11:2];
            CacheOp_C <= 3'b110; // CacheOpD_Adr_HWb
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr_in;
            PAddressValid_C <= valid_in;
            CacheAttr_C <= 3'b111;
            DoCacheOp_C <= 1'b0;
        end
        check_hit(exp_hit);
        wait_ready();
    end
    endtask

    // Task cache address hit writeback invalidate (no verification)
    task cache_addrhwbinv;
    input [11:0] vaddr_in;
    input [23:0] paddr_in;
    input valid_in;
    input exp_hit;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in[11:2];
            CacheOp_C <= 3'b101; // CacheOpD_Adr_HWbInv
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr_in;
            PAddressValid_C <= valid_in;
            CacheAttr_C <= 3'b111;
            DoCacheOp_C <= 1'b0;
        end
        check_hit(exp_hit);
        wait_ready();
    end
    endtask

    // Task cache index writeback invalidate (no verification)
    task cache_idxwbinv;
    input [5:0] idx_in;
    input setAsel_in;
    begin
        @(posedge clock) begin
            VAddressIn_C <= {1'b0, setAsel_in, idx_in, 2'b00};
            CacheOp_C <= 3'b000; // CacheOpD_Idx_WbInv
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= {24{1'b0}}; // set selection is part of VAddress for a 2KB cache
            PAddressValid_C <= 1'b1;
            DoCacheOp_C <= 1'b0;
        end
        wait_ready();
    end
    endtask

    // Task cache index store tag (no verification)
    task cache_idxstag;
    input [5:0] idx_in;
    input setAsel_in;
    input [27:0] data_in;
    begin
        @(posedge clock) begin
            VAddressIn_C <= {1'b0, setAsel_in, idx_in, 2'b00};
            CacheOpData_C <= data_in;
            CacheOp_C <= 3'b010; // CacheOpD_Idx_STag
            DoCacheOp_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= {24{1'b0}};
            PAddressValid_C <= 1'b1;
            DoCacheOp_C <= 1'b0;
        end
        wait_ready();
    end
    endtask;

    // Task cache reset (index store tag 0s for all indices)
    task cache_reset;
    begin
        for (j = 0; j < 64; j = j + 1) begin
            cache_idxstag(j[5:0], 1'b0, {28{1'b0}});
            cache_idxstag(j[5:0], 1'b1, {28{1'b0}});
        end
    end
    endtask

    // Task read
    task read;
    input [11:0] vaddr_in;
    input [23:0] paddr_in;
    input cache_in;         // cacheable or not (1/0)
    input valid_in;         // paddress is valid
    input exp_hitmiss;      // expected hit or miss
    input [31:0] exp_data;  // expected output data
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in[11:2];
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

    // Task write (hit verification but no data verification)
    task write;
    input [11:0] vaddr_in;
    input [23:0] paddr_in;
    input cache_in;
    input valid_in;
    input exp_hitmiss;
    input [31:0] data_in;
    input [3:0]  write_in;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr_in[11:2];
            DataIn_C <= data_in;
            Write_C <= write_in;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr_in;
            PAddressValid_C <= valid_in;
            CacheAttr_C <= {1'b0, ~cache_in, 1'b0}; // 3'b010 is uncacheable
            VAddressIn_C <= 10'h0;  // arbitrary
            Write_C <= 4'h0;
        end
        check_hit(exp_hitmiss);
        wait_ready();
    end
    endtask

    // Task read pipelined
    task read_pipe;
    input [11:0] vaddr1_in;
    input [23:0] paddr1_in;
    input cache1_in;
    input valid1_in;
    input exp_hitmiss1;
    input [31:0] exp_data1;
    input [11:0] vaddr2_in;
    input [23:0] paddr2_in;
    input cache2_in;
    input valid2_in;
    input exp_hitmiss2;
    input [31:0] exp_data2;
    begin
        @(posedge clock) begin
            VAddressIn_C <= vaddr1_in[11:2];
            Read_C <= 1'b1;
        end
        @(posedge clock) begin
            PAddressIn_C <= paddr1_in;
            PAddressValid_C <= valid1_in;
            CacheAttr_C <= {1'b0, ~cache1_in, 1'b0};
            VAddressIn_C <= vaddr2_in[11:2];
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
        if (uut.s_hit_e != exp_hit) begin
            $display("Fail: s_hit_e: %b (%b expected).", uut.s_hit_e, exp_hit);
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

