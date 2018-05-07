`timescale 1 ns / 10 ps
/*
 * File         : mips_test.v
 * Project      : MIPS32 MUX
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A top-level MIPS32r1 (processor + caches) test harness.
 *
 *   A test consists of a user-supplied program (given in three memory images)
 *   which writes a 1 (success) or 0 (failure) to a special test register.
 *
 *   The three input memory images correspond to different physical memory regions:
 *     1. Kernel Low (klo)    : [0x00000000 - 0x00004000) (16 KiB)
 *     2. Kernel High (khi)   : [0x1fc00000 - 0x1fc04000) (16 KiB)
 *     3. Virtual memory (vm) : [0x80000000 - 0x80040000) (256 KiB)
 *
 *   The khi region contains the boot code. The processor starts at virtual address
 *   0xbfc00000 which  always maps to physical address 0x1fc00000. Hence khi begins
 *   there and is currently sized to 16 KiB.
 *
 *   The klo region contains the exception vectors which map to very low addresses.
 *   It is currently sized to 16 KiB.
 *
 *   The vm region is for user code. It is called "virtual" because the user code
 *   assumes it starts at virtual address zero which actually translates to
 *   physical address 0x80000000. It is the only memory region which is fully-mapped
 *   and cacheable.
 *
 *   In addition to the three memory regions, there are five 32-bit test registers:
 *     1. Reset Register   : 0x1fffffec  (virtual 0xbfffffec)
 *     2. Command Register : 0x1ffffff0  (virtual 0xbffffff0)
 *     3. Status Register  : 0x1ffffff4  (virtual 0xbffffff4)
 *     4. Test Register    : 0x1ffffff8  (virtual 0xbffffff8)
 *     5. Scratch Register : 0x1ffffffc  (virtual 0xbffffffc)
 *
 *   - The reset register allows software to reset the processor after a chosen delay.
 *     Write a value to the register and each cycle it will decrement by one (until 0).
 *     When the register equals 1, the processor will be reset.
 *   - The command register provides information to the test program. It is not
 *     currently used.
 *   - The status register notifies the test harness on behalf of the processor:
 *     - Setting bit 0 (0x1) terminates the test
 *     - Setting bit 1 (0x2) dumps a 1 KiB memory buffer at address 0x1fc03c00
 *       the the stdout log file (if enabled via command line arguments). The
 *       buffer is treated as a C-string and is copied until NULL or the end
 *       of the buffer is reached.
 *   - The test register is set to 1 (success) or 0 (failure) before the test terminates.
 *   - The scratch register may be used arbitrarily by tests.
 */
module mips_test();

    localparam PABITS=32;
    localparam Big_Endian = 1'b0;   // For now this must be updated manually

    reg clock;
    reg reset;

    // Processor command, status, and test registers.
    reg [31:0] mips_rst_reg;    // Byte address 0x1fffffec
    reg [31:0] mips_cmd_reg;    // Byte address 0x1ffffff0
    reg [31:0] mips_sta_reg;    // Byte address 0x1ffffff4
    reg [31:0] mips_tst_reg;    // Byte address 0x1ffffff8
    reg [31:0] mips_scr_reg;    // Byte address 0x1ffffffc

    // Testbench parameters.
    integer read_khigh_mem;
    integer read_klow_mem;
    integer read_vm_mem;
    integer write_test_result;
    integer write_scratch_result;
    integer write_test_cycles;
    integer dump_vars;
    integer itrace;
    integer regtrace;
    integer stdout;
    integer itrace_handle;
    integer regtrace_handle;
    integer stdout_handle;
    integer i, j;

    reg  [1024*8:1] khigh_mem_filename;
    reg  [1024*8:1] klow_mem_filename;
    reg  [1024*8:1] vm_mem_filename;
    reg  [1024*8:1] test_result_filename;
    reg  [1024*8:1] test_scratch_filename;
    reg  [1024*8:1] test_cycles_filename;
    reg  [1024*8:1] dump_vars_filename;
    reg  [1024*8:1] itrace_filename;
    reg  [1024*8:1] regtrace_filename;
    reg  [1024*8:1] stdout_filename;

    reg  [32:1] num_cycles = 32'hFFFFFFFF;
    reg  [32:1] cycle_count = 0;

    // Initialize testbench parameters.
    integer result;
    initial begin

        read_khigh_mem       = $value$plusargs("khigh_mem=%s", khigh_mem_filename);
        read_klow_mem        = $value$plusargs("klow_mem=%s",  klow_mem_filename);
        read_vm_mem          = $value$plusargs("vm_mem=%s",    vm_mem_filename);
        write_test_result    = $value$plusargs("test_result=%s", test_result_filename);
        write_scratch_result = $value$plusargs("scratch_result=%s", test_scratch_filename);
        write_test_cycles    = $value$plusargs("test_cycles=%s", test_cycles_filename);
        dump_vars            = $value$plusargs("dumpvars=%s", dump_vars_filename);
        itrace               = $value$plusargs("itrace=%s", itrace_filename);
        regtrace             = $value$plusargs("regtrace=%s", regtrace_filename);
        stdout               = $value$plusargs("stdout=%s", stdout_filename);

        // Fill memories
        if (read_khigh_mem) begin
            $display("Kernel High Memory: %0s", khigh_mem_filename);
            $readmemh(khigh_mem_filename, khigh_mem.MainRAM.ram);
        end else begin
            $display("No kernel high memory");
        end
        if (read_klow_mem) begin
            $display("Kernel Low Memory: %0s", klow_mem_filename);
            $readmemh(klow_mem_filename, klow_mem.MainRAM.ram);
        end else begin
            $display("No kernel low memory");
        end
        if (read_vm_mem) begin
            $display("Virtual memory: %0s", vm_mem_filename);
            $readmemh(vm_mem_filename, vm_mem.MainRAM.ram);
        end else begin
            $display("No virtual memory region");
        end

        // Instruction trace status
        if (itrace) begin
            $display("Instruction trace enabled: %0s", itrace_filename);
        end

        // Register file trace status
        if (regtrace) begin
            $display("Register file trace enabled: %0s", regtrace_filename);
        end

        // Stdout status
        if (stdout) begin
            $display("Stdout enabled: %0s", stdout_filename);
        end

        // Cycle limit
        if ($test$plusargs("cycles")) begin
            result = $value$plusargs("cycles=%d", num_cycles);
        end
        $display("Running userlogic for maximum of %0d cycles", num_cycles);

    end

    initial begin

        // Initialize testbench signals
        clock = 1'b0;
        reset = 1'b1;
        mips_cmd_reg = {32{1'b0}};

        // Create waveform dump
        if (dump_vars) begin
            $dumpfile(dump_vars_filename);
            $dumpvars(0, mips_test);
        end

        // Open the instruction trace (if enabled)
        if (itrace) begin
            itrace_handle = $fopen(itrace_filename, "w");
        end

        // Open the register file trace (if enabled)
        if (regtrace) begin
            regtrace_handle = $fopen(regtrace_filename, "w");
        end

        // Open the stdout log file (if enabled)
        if (stdout) begin
            stdout_handle = $fopen(stdout_filename, "w");
        end

        // Turn off reset after a few cycles
        #20;
        reset = 1'b0;
        mips_cmd_reg[1] = 1'b0;

        // Run
        #10 mips_cmd_reg[0] = 1'b1;


        cycle_count = num_cycles;
        while (cycle_count > 0 & ~mips_sta_reg[0]) begin
            cycle_count = cycle_count - 1;
            reset = (mips_rst_reg == 32'd1);

            // Conditionally output an instruction trace element
            if (itrace && mips32_top.Core.W1_Issued) begin
                // NOTE: 'W1_Issued' does not currently capture an instruction
                // that is an exception (e.g., syscall), thus the trace will
                // miss any such instructions.
                //$fwrite(itrace_handle, "%08h\n", mips32_top.Core.W1_RestartPC);

                // Note: Use this to add a time reference next to each instruction:
                $fwrite(itrace_handle, "%08h    (%0d)\n", mips32_top.Core.W1_RestartPC, $stime);
            end

            // Conditionally output a register file trace element
            if (regtrace && mips32_top.Core.W1_Issued) begin
                $fwrite(regtrace_handle, "%0d at=%08h v0=%08h v1=%08h a0=%08h a1=%08h a2=%08h a3=%08h t0=%08h t1=%08h t2=%08h t3=%08h t4=%08h t5=%08h t6=%08h t7=%08h s0=%08h s1=%08h s2=%08h s3=%08h s4=%08h s5=%08h s6=%08h s7=%08h t8=%08h t9=%08h k0=%08h k1=%08h gp=%08h sp=%08h fp=%08h ra=%08h hi=%08h lo=%08h\n",
                  $stime, mips32_top.Core.RegisterFile.registers[1], mips32_top.Core.RegisterFile.registers[2],
                  mips32_top.Core.RegisterFile.registers[3], mips32_top.Core.RegisterFile.registers[4], mips32_top.Core.RegisterFile.registers[5],
                  mips32_top.Core.RegisterFile.registers[6], mips32_top.Core.RegisterFile.registers[7], mips32_top.Core.RegisterFile.registers[8],
                  mips32_top.Core.RegisterFile.registers[9], mips32_top.Core.RegisterFile.registers[10], mips32_top.Core.RegisterFile.registers[11],
                  mips32_top.Core.RegisterFile.registers[12], mips32_top.Core.RegisterFile.registers[13], mips32_top.Core.RegisterFile.registers[14],
                  mips32_top.Core.RegisterFile.registers[15], mips32_top.Core.RegisterFile.registers[16], mips32_top.Core.RegisterFile.registers[17],
                  mips32_top.Core.RegisterFile.registers[18], mips32_top.Core.RegisterFile.registers[19], mips32_top.Core.RegisterFile.registers[20],
                  mips32_top.Core.RegisterFile.registers[21], mips32_top.Core.RegisterFile.registers[22], mips32_top.Core.RegisterFile.registers[23],
                  mips32_top.Core.RegisterFile.registers[24], mips32_top.Core.RegisterFile.registers[25], mips32_top.Core.RegisterFile.registers[26],
                  mips32_top.Core.RegisterFile.registers[27], mips32_top.Core.RegisterFile.registers[28], mips32_top.Core.RegisterFile.registers[29],
                  mips32_top.Core.RegisterFile.registers[30], mips32_top.Core.RegisterFile.registers[31], mips32_top.Core.ALU.HI.Q, mips32_top.Core.ALU.LO.Q
                );
            end

            // Conditionally print the output buffer to the stdout file log
            // (e.g., 'printf', enabled by bit 1 of the status register)
            if (stdout && mips_sta_reg[1]) begin
                // Print the 1 KiB buffer, ending if NULL is found
                begin: LOOP
                    for (i = 0; i < 1024; i = i + 1) begin
                        if (Big_Endian == 1'b1) begin
                            j[7:0] = khigh_mem.MainRAM.ram[960 + i[31:4]] [(i[3:0]*8)+7 : (i[3:0]*8)];
                        end
                        else begin
                            j[7:0] = khigh_mem.MainRAM.ram[960 + i[31:4]] [((15-i[3:0])*8)+7 : (15-i[3:0])*8];
                        end
                        if (j[7:0] == 8'h00) begin
                            disable LOOP;
                        end
                        else begin
                            $fwrite(stdout_handle, "%c", j[7:0]);
                            $fflush(stdout_handle);
                        end
                    end
                end
                mips_sta_reg[1] = 1'b0;
            end
            #10;
        end

        // Close output files
        if (itrace) begin
            $fclose(itrace_handle);
        end
        if (stdout) begin
            $fclose(stdout_handle);
        end

        $display("Test ran for %0d cycles", num_cycles - cycle_count);
        $display("status register = %0d", mips_sta_reg);
        $display("test register = %0d", mips_tst_reg);
        $display("scratch register = %0d", mips_scr_reg);

        mips_cmd_reg[0] = 1'b0;

        // Write the test result.
        if (write_test_result) begin
            i = $fopen(test_result_filename, "w");
            $fwrite(i, "%0d\n", mips_tst_reg);
            $fclose(i);
        end

        // Write the scratch result.
        if (write_scratch_result) begin
            i = $fopen(test_scratch_filename, "w");
            $fwrite(i, "0x%0h\n", mips_scr_reg);
            $fclose(i);
        end

        // Write the number of test cycles.
        if (write_test_cycles) begin
            i = $fopen(test_cycles_filename, "w");
            $fwrite(i, "%0d\n", num_cycles - cycle_count);
            $fclose(i);
        end

        $finish;
    end

    initial forever begin
        #5 clock = ~clock;
    end

    // Memory signals
    wire [11:0]  khigh_I_Address;
    wire [31:0]  khigh_I_DataOut;
    wire         khigh_I_Ready;
    wire [1:0]   khigh_I_DataOutOffset;
    wire         khigh_I_ReadLine;
    wire         khigh_I_ReadWord;
    wire [11:0]  khigh_D_Address;
    wire [127:0] khigh_D_DataIn;
    wire         khigh_D_LineInReady;
    wire         khigh_D_WordInReady;
    wire [3:0]   khigh_D_WordInBE;
    wire [31:0]  khigh_D_DataOut;
    wire [1:0]   khigh_D_DataOutOffset;
    wire         khigh_D_ReadLine;
    wire         khigh_D_ReadWord;
    wire         khigh_D_Ready;
    wire [11:0]  klow_I_Address;
    wire [31:0]  klow_I_DataOut;
    wire         klow_I_Ready;
    wire [1:0]   klow_I_DataOutOffset;
    wire         klow_I_ReadLine;
    wire         klow_I_ReadWord;
    wire [11:0]  klow_D_Address;
    wire [127:0] klow_D_DataIn;
    wire         klow_D_LineInReady;
    wire         klow_D_WordInReady;
    wire [3:0]   klow_D_WordInBE;
    wire [31:0]  klow_D_DataOut;
    wire [1:0]   klow_D_DataOutOffset;
    wire         klow_D_ReadLine;
    wire         klow_D_ReadWord;
    wire         klow_D_Ready;
    wire [15:0]  vm_I_Address;
    wire [31:0]  vm_I_DataOut;
    wire         vm_I_Ready;
    wire [1:0]   vm_I_DataOutOffset;
    wire         vm_I_ReadLine;
    wire         vm_I_ReadWord;
    wire [15:0]  vm_D_Address;
    wire [127:0] vm_D_DataIn;
    wire         vm_D_LineInReady;
    wire         vm_D_WordInReady;
    wire [3:0]   vm_D_WordInBE;
    wire [31:0]  vm_D_DataOut;
    wire [1:0]   vm_D_DataOutOffset;
    wire         vm_D_ReadLine;
    wire         vm_D_ReadWord;
    wire         vm_D_Ready;

    // Processor signals
    wire [(PABITS-3):0] InstMem_Address;
    wire                InstMem_ReadLine;
    wire                InstMem_ReadWord;
    wire                InstMem_Ready;
    wire [31:0]         InstMem_In;
    wire [1:0]          InstMem_Offset;
    wire [(PABITS-3):0] DataMem_Address;
    wire                DataMem_ReadLine;
    wire                DataMem_ReadWord;
    reg  [31:0]         DataMem_In;
    wire                DataMem_Ready;
    wire [1:0]          DataMem_Offset;
    wire                DataMem_WriteLineReady;
    wire                DataMem_WriteWordReady;
    wire [3:0]          DataMem_WriteWordBE;
    wire [127:0]        DataMem_Out;
    wire [4:0]          Interrupts = {5{1'b0}};
    wire                NMI = 1'b0;

    // Selection signals (word addresses)
    wire khigh_sel_i  = (InstMem_Address >= 30'h07f00000) && (InstMem_Address < 30'h07f01000);
    wire khigh_sel_d  = (DataMem_Address >= 30'h07f00000) && (DataMem_Address < 30'h07f01000);
    wire klow_sel_i   = (InstMem_Address < 30'h1000);
    wire klow_sel_d   = (DataMem_Address < 30'h1000);
    wire vm_sel_i     = (InstMem_Address >= 30'h20000000);
    wire vm_sel_d     = (DataMem_Address >= 30'h20000000);
    wire rst_sel_d    = (DataMem_Address == 30'h07fffffb);
    wire cmd_sel_d    = (DataMem_Address == 30'h07fffffc);
    wire status_sel_d = (DataMem_Address == 30'h07fffffd);
    wire test_sel_d   = (DataMem_Address == 30'h07fffffe);
    wire scr_sel_d    = (DataMem_Address == 30'h07ffffff);

    // Kernel high memory - 16 KiB [0x1fc00000 - 0x1fc04000)
    // NOTE: Currently using last 1 KiB for an output buffer [0x1fc03c00 - 0x1fc04000)
    MainMemory #(.ADDR_WIDTH(10)) khigh_mem (
        .clock            (clock),
        .reset            (reset),
        .I_Address        (khigh_I_Address),
        .I_DataIn         ({128{1'b0}}),
        .I_DataOut        (khigh_I_DataOut),
        .I_Ready          (khigh_I_Ready),
        .I_DataOutOffset  (khigh_I_DataOutOffset),
        .I_BootWrite      (1'b0),
        .I_ReadLine       (khigh_I_ReadLine),
        .I_ReadWord       (khigh_I_ReadWord),
        .D_Address        (khigh_D_Address),
        .D_DataIn         (khigh_D_DataIn),
        .D_LineInReady    (khigh_D_LineInReady),
        .D_WordInReady    (khigh_D_WordInReady),
        .D_WordInBE       (khigh_D_WordInBE),
        .D_DataOut        (khigh_D_DataOut),
        .D_DataOutOffset  (khigh_D_DataOutOffset),
        .D_ReadLine       (khigh_D_ReadLine),
        .D_ReadWord       (khigh_D_ReadWord),
        .D_Ready          (khigh_D_Ready)
    );

    // Kernel low memory - 16 KiB [0x00000000 - 0x00004000)
    MainMemory #(.ADDR_WIDTH(10)) klow_mem (
        .clock            (clock),
        .reset            (reset),
        .I_Address        (klow_I_Address),
        .I_DataIn         ({128{1'b0}}),
        .I_DataOut        (klow_I_DataOut),
        .I_Ready          (klow_I_Ready),
        .I_DataOutOffset  (klow_I_DataOutOffset),
        .I_BootWrite      (1'b0),
        .I_ReadLine       (klow_I_ReadLine),
        .I_ReadWord       (klow_I_ReadWord),
        .D_Address        (klow_D_Address),
        .D_DataIn         (klow_D_DataIn),
        .D_LineInReady    (klow_D_LineInReady),
        .D_WordInReady    (klow_D_WordInReady),
        .D_WordInBE       (klow_D_WordInBE),
        .D_DataOut        (klow_D_DataOut),
        .D_DataOutOffset  (klow_D_DataOutOffset),
        .D_ReadLine       (klow_D_ReadLine),
        .D_ReadWord       (klow_D_ReadWord),
        .D_Ready          (klow_D_Ready)
    );

    // Virtual memory - 256 KiB [0x80000000 - 0x80040000)
    MainMemory #(.ADDR_WIDTH(14)) vm_mem (
        .clock            (clock),
        .reset            (reset),
        .I_Address        (vm_I_Address),
        .I_DataIn         ({128{1'b0}}),
        .I_DataOut        (vm_I_DataOut),
        .I_Ready          (vm_I_Ready),
        .I_DataOutOffset  (vm_I_DataOutOffset),
        .I_BootWrite      (1'b0),
        .I_ReadLine       (vm_I_ReadLine),
        .I_ReadWord       (vm_I_ReadWord),
        .D_Address        (vm_D_Address),
        .D_DataIn         (vm_D_DataIn),
        .D_LineInReady    (vm_D_LineInReady),
        .D_WordInReady    (vm_D_WordInReady),
        .D_WordInBE       (vm_D_WordInBE),
        .D_DataOut        (vm_D_DataOut),
        .D_DataOutOffset  (vm_D_DataOutOffset),
        .D_ReadLine       (vm_D_ReadLine),
        .D_ReadWord       (vm_D_ReadWord),
        .D_Ready          (vm_D_Ready)
    );

    // Processor + Caches
    MIPS32 #(.PABITS(PABITS)) mips32_top (
        .clock                   (clock),
        .reset                   (reset),
        .Core_Reset              (reset),
        .InstMem_Address         (InstMem_Address),
        .InstMem_ReadLine        (InstMem_ReadLine),
        .InstMem_ReadWord        (InstMem_ReadWord),
        .InstMem_Ready           (InstMem_Ready),
        .InstMem_In              (InstMem_In),
        .InstMem_Offset          (InstMem_Offset),
        .DataMem_Address         (DataMem_Address),
        .DataMem_ReadLine        (DataMem_ReadLine),
        .DataMem_ReadWord        (DataMem_ReadWord),
        .DataMem_In              (DataMem_In),
        .DataMem_Ready           (DataMem_Ready),
        .DataMem_Offset          (DataMem_Offset),
        .DataMem_WriteLineReady  (DataMem_WriteLineReady),
        .DataMem_WriteWordReady  (DataMem_WriteWordReady),
        .DataMem_WriteWordBE     (DataMem_WriteWordBE),
        .DataMem_Out             (DataMem_Out),
        .Interrupts              (Interrupts),
        .NMI                     (NMI)
    );

    // Memory assignments
    assign khigh_I_Address     = InstMem_Address[11:0];
    assign klow_I_Address      = InstMem_Address[11:0];
    assign vm_I_Address        = InstMem_Address[15:0];
    assign khigh_I_ReadLine    = InstMem_ReadLine & khigh_sel_i;
    assign klow_I_ReadLine     = InstMem_ReadLine & klow_sel_i;
    assign vm_I_ReadLine       = InstMem_ReadLine & vm_sel_i;
    assign khigh_I_ReadWord    = InstMem_ReadWord & khigh_sel_i;
    assign klow_I_ReadWord     = InstMem_ReadWord & klow_sel_i;
    assign vm_I_ReadWord       = InstMem_ReadWord & vm_sel_i;
    assign khigh_D_Address     = DataMem_Address[11:0];
    assign klow_D_Address      = DataMem_Address[11:0];
    assign vm_D_Address        = DataMem_Address[15:0];
    assign khigh_D_DataIn      = DataMem_Out;
    assign klow_D_DataIn       = DataMem_Out;
    assign vm_D_DataIn         = DataMem_Out;
    assign khigh_D_LineInReady = DataMem_WriteLineReady & khigh_sel_d;
    assign klow_D_LineInReady  = DataMem_WriteLineReady & klow_sel_d;
    assign vm_D_LineInReady    = DataMem_WriteLineReady & vm_sel_d;
    assign khigh_D_WordInReady = DataMem_WriteWordReady & khigh_sel_d;
    assign klow_D_WordInReady  = DataMem_WriteWordReady & klow_sel_d;
    assign vm_D_WordInReady    = DataMem_WriteWordReady & vm_sel_d;
    assign khigh_D_WordInBE    = DataMem_WriteWordBE;
    assign klow_D_WordInBE     = DataMem_WriteWordBE;
    assign vm_D_WordInBE       = DataMem_WriteWordBE;
    assign khigh_D_ReadLine    = DataMem_ReadLine & khigh_sel_d;
    assign klow_D_ReadLine     = DataMem_ReadLine & klow_sel_d;
    assign vm_D_ReadLine       = DataMem_ReadLine & vm_sel_d;
    assign khigh_D_ReadWord    = DataMem_ReadWord & khigh_sel_d;
    assign klow_D_ReadWord     = DataMem_ReadWord & klow_sel_d;
    assign vm_D_ReadWord       = DataMem_ReadWord & vm_sel_d;

    // Processor assignments
    // Restrictions: The cmd/status/test/scr registers cannot be read by instruction memory. They can only be written as a full word.
    assign InstMem_Ready  = (khigh_I_Ready & khigh_sel_i) | (klow_I_Ready & klow_sel_i) | (vm_I_Ready & vm_sel_i);
    assign InstMem_In     = (khigh_sel_i) ? khigh_I_DataOut : ((klow_sel_i) ? klow_I_DataOut : vm_I_DataOut);
    assign InstMem_Offset = (khigh_sel_i) ? khigh_I_DataOutOffset : ((klow_sel_i) ? klow_I_DataOutOffset : vm_I_DataOutOffset);

    // Allow reading from the test registers by signaling 'Ready' one cycle after the read command
    reg DataMem_ReadWord_r;
    always @(posedge clock) begin
        DataMem_ReadWord_r <= DataMem_ReadWord;
    end

    assign DataMem_Ready  = (khigh_D_Ready & khigh_sel_d) | (klow_D_Ready & klow_sel_d) | (vm_D_Ready & vm_sel_d) |
                            ((DataMem_WriteWordReady | DataMem_ReadWord_r) & |{rst_sel_d, cmd_sel_d, status_sel_d, test_sel_d, scr_sel_d});
    assign DataMem_Offset = (khigh_sel_d) ? khigh_D_DataOutOffset : ((klow_sel_d) ? klow_D_DataOutOffset : vm_D_DataOutOffset);

    // If little-endian, swap the bytes of the test registers so they are consistent
    // (These registers are not byte-addressable anyway)
    wire [31:0] DataMem_Out_Endian;
    wire [31:0] mips_rst_endian;
    wire [31:0] mips_cmd_endian;
    wire [31:0] mips_sta_endian;
    wire [31:0] mips_tst_endian;
    wire [31:0] mips_scr_endian;
    generate
        if (Big_Endian == 1'b1) begin
            assign DataMem_Out_Endian = DataMem_Out;
            assign mips_rst_endian = mips_rst_reg;
            assign mips_cmd_endian = mips_cmd_reg;
            assign mips_sta_endian = mips_sta_reg;
            assign mips_tst_endian = mips_tst_reg;
            assign mips_scr_endian = mips_scr_reg;
        end
        else begin
            assign DataMem_Out_Endian = {DataMem_Out[7:0], DataMem_Out[15:8], DataMem_Out[23:16], DataMem_Out[31:24]};
            assign mips_rst_endian = {mips_rst_reg[7:0], mips_rst_reg[15:8], mips_rst_reg[23:16], mips_rst_reg[31:24]};
            assign mips_cmd_endian = {mips_cmd_reg[7:0], mips_cmd_reg[15:8], mips_cmd_reg[23:16], mips_cmd_reg[31:24]};
            assign mips_sta_endian = {mips_sta_reg[7:0], mips_sta_reg[15:8], mips_sta_reg[23:16], mips_sta_reg[31:24]};
            assign mips_tst_endian = {mips_tst_reg[7:0], mips_tst_reg[15:8], mips_tst_reg[23:16], mips_tst_reg[31:24]};
            assign mips_scr_endian = {mips_scr_reg[7:0], mips_scr_reg[15:8], mips_scr_reg[23:16], mips_scr_reg[31:24]};
        end
    endgenerate

    always @(*) begin
        if (khigh_sel_d) begin
            DataMem_In = khigh_D_DataOut;
        end
        if (klow_sel_d) begin
            DataMem_In = klow_D_DataOut;
        end
        if (vm_sel_d) begin
            DataMem_In = vm_D_DataOut;
        end
        if (rst_sel_d) begin
            DataMem_In = mips_rst_endian;
        end
        if (cmd_sel_d) begin
            DataMem_In = mips_cmd_endian;
        end
        if (status_sel_d) begin
            DataMem_In = mips_sta_endian;
        end
        if (test_sel_d) begin
            DataMem_In = mips_tst_endian;
        end
        if (scr_sel_d) begin
            DataMem_In = mips_scr_endian;
        end
    end

    // Special register assignments
    always @(posedge clock) begin
        if (reset) begin
            mips_rst_reg <= {32{1'b0}};
            mips_sta_reg <= {32{1'b0}};
            mips_tst_reg <= {32{1'b0}};
            mips_scr_reg <= {32{1'b0}};
        end
        else begin
            mips_rst_reg <= (rst_sel_d    & DataMem_WriteWordReady) ? DataMem_Out_Endian[31:0] : ((mips_rst_reg > 32'd0) ? mips_rst_reg - 1 : mips_rst_reg);
            mips_sta_reg <= (status_sel_d & DataMem_WriteWordReady) ? DataMem_Out_Endian[31:0] : mips_sta_reg;
            mips_tst_reg <= (test_sel_d   & DataMem_WriteWordReady) ? DataMem_Out_Endian[31:0] : mips_tst_reg;
            mips_scr_reg <= (scr_sel_d    & DataMem_WriteWordReady) ? DataMem_Out_Endian[31:0] : mips_scr_reg;
        end
    end

endmodule
