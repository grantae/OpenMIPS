`timescale 1ns / 1ps
/*
 * File         : InstructionCache_8KB.v
 * Project      : XUM MIPS32 cache enhancement
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   An instruction cache for the MIPS32 Release 1 processor core.
 */
module InstructionCache_8KB #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    // Processor Interface
    input  [9:0]           VAddressIn_C,    // Bits [11:2]  of the 32-bit virtual address, i.e. the offset of the vpage/pframe.
    input  [(PABITS-13):0] PAddressIn_C,    // Bits [35:12] of the 36-bit physical address, i.e. the TLB-translated physical tag.
    input                  PAddressValid_C, // The physical address is valid (TLB hit).
    input  [2:0]           CacheAttr_C,     // Cache attributes for the requested address.
    input                  Stall_C,
    input                  Read_C,
    output [31:0]          DataOut_C,
    output                 Ready_C,
    output reg             Blocked_C,       // Similar to ~Ready_C, but high when an invalid PAddress is not enough to abort
    input                  DoCacheOp_C,     // Synchronous pulse indicating a CACHE operation (i.e. from WB when not stalled).
    input  [2:0]           CacheOp_C,       // Cache operation, encoded in CACHE instruction.
    input  [(PABITS-11):0] CacheOpData_C,   // Store Tag data (PABITS-11:2->Tag, 1:0->Valid, [!0 is valid]).
    // Memory Interface
    output [(PABITS-3):0]  Address_M,       // Physical line (33:2) or word (33:0) address for memory requests.
    output                 ReadLine_M,      // Initiates a cacheline (128-bit) read sequence from memory starting at a word address.
    output                 ReadWord_M,      // Initiates a read for a single 32-bit uncacheable word.
    input  [31:0]          DataIn_M,        // Inbound data from memory.
    input  [1:0]           DataInOffset_M,  // Cacheline word offset (0, 1, 2, or 3) of the incoming data from memory following 'ReadLine_M'.
    input                  Ready_M          // 1-cycle pulse indicating one word of valid read data or capture of write data.
    );

    `include "../../Core/MIPS_Defines.v"

    /* Cache parameters:
     *   Size: 8 KiB
     *   Block size: 16 bytes (4 32-bit words)
     *   Associativity: 2-way
     */

    /* Supported cache operations:
     *   - CacheOpI_Idx_Inv:  Index invalidate
     *   - CacheOpI_Idx_STag: Index store tag
     *   - CacheOpI_Adr_HInv: Address hit invalidate
     */
    localparam [3:0] IDLE=0, READ_CHECK=1, WAIT_WORD_MEM=2, WAIT_FILL_1=3, WAIT_FILL_2=4, WAIT_FILL_3=5, WAIT_FILL_4=6,
                     WAIT_WORD_CPU=7, WAIT_LINE_CPU=8, COP_CHECK_IDX_INV=9, COP_CHECK_IDX_STAG=10, COP_CHECK_ADR_HINV=11,
                     WRITE_RECOVER=12;

    // Local signals
    wire [31:0]          captured_mem_data;
    wire                 capture_mem;
    reg  [3:0]           cmd_or_idle;
    wire                 evict;
    wire                 hit_any;
    wire [7:0]           index, saved_index;
    reg                  lru [0:255];
    reg                  new_read;
    reg  [3:0]           next_state;
    wire [1:0]           offset, saved_offset;
    reg                  ready;
    wire [(PABITS-11):0] saved_stag_data;
    wire                 set_select_a;
    wire [31:0]          sets_word_out;
    wire [3:0]           state;
    wire                 uncacheable;
    // Submodule commands
    reg                  cmd_fill_line;   // Write a word of data from memory to the cache (uses LineIndex, LineOffset, LineIn)
    reg                  cmd_inv_line;    // Invalidate a tag (uses Tag, Index)
    wire                 cmd_val_line;    // Validate and store a tag (uses Tag, Index)
    wire                 cmd_stag;        // Store a custom tag from software (uses Index, StoreTagData)
    reg                  cmd_select_a;    // Operate on set A (otherwise B)

    // Set signals
    wire [(PABITS-13):0] SetA_Tag,            SetB_Tag;
    wire [7:0]           SetA_Index,          SetB_Index;
    wire [1:0]           SetA_Offset,         SetB_Offset;
    wire [7:0]           SetA_LineIndex,      SetB_LineIndex;
    wire [1:0]           SetA_LineOffset,     SetB_LineOffset;
    wire [31:0]          SetA_WordOut,        SetB_WordOut;
    wire                 SetA_Hit,            SetB_Hit;
    wire                 SetA_Valid,          SetB_Valid;
    wire [31:0]          SetA_LineIn,         SetB_LineIn;
    wire                 SetA_ValidateLine,   SetB_ValidateLine;
    wire                 SetA_InvalidateLine, SetB_InvalidateLine;
    wire                 SetA_FillLine,       SetB_FillLine;
    wire                 SetA_StoreTag,       SetB_StoreTag;
    wire [(PABITS-11):0] SetA_StoreTagData,   SetB_StoreTagData;

    // Top-level assignments
    //
    // NOTE: The processor can cancel a request by keeping PAddressValid_C low at the appropriate time (e.g., READ_CHECK, *CHECK*).
    // This occurs during pipeline flushes when the i-cache is not blocked (via high Blocked_C).
    // In this case the processor does not wait for Ready_C!
    assign DataOut_C  = ((state == WAIT_WORD_CPU) | (state == WAIT_LINE_CPU)) ? captured_mem_data : sets_word_out;
    assign Ready_C = ready;
    always @(*) begin
        case (state)
            READ_CHECK:         ready = ~PAddressValid_C | (PAddressValid_C & ~uncacheable & hit_any);
            COP_CHECK_IDX_INV:  ready = ~PAddressValid_C;
            COP_CHECK_IDX_STAG: ready = ~PAddressValid_C;
            COP_CHECK_ADR_HINV: ready = ~PAddressValid_C;
            WAIT_WORD_CPU:      ready = 1'b1;
            WAIT_LINE_CPU:      ready = 1'b1;
            WRITE_RECOVER:      ready = 1'b1;
            default:            ready = 1'b0;
        endcase
    end
    always @(*) begin
        case (state)
            WAIT_WORD_MEM: Blocked_C = 1'b1;
            WAIT_FILL_1:   Blocked_C = 1'b1;
            WAIT_FILL_2:   Blocked_C = 1'b1;
            WAIT_FILL_3:   Blocked_C = 1'b1;
            WAIT_FILL_4:   Blocked_C = 1'b1;
            default:       Blocked_C = 1'b0;
        endcase
    end
    assign Address_M  = {PAddressIn_C, saved_index, saved_offset};
    assign ReadLine_M = (state == READ_CHECK) & PAddressValid_C & ~hit_any & ~uncacheable;
    assign ReadWord_M = (state == READ_CHECK) & PAddressValid_C & uncacheable;

    // Local Assignments
    assign capture_mem   = Ready_M & (uncacheable | (DataInOffset_M == saved_offset));
    assign evict         = SetA_Valid & ~SetA_Hit & SetB_Valid & ~SetB_Hit;
    assign index         = VAddressIn_C[9:2];
    assign offset        = VAddressIn_C[1:0];
    assign set_select_a  = ~SetA_Valid | (evict & ~lru[saved_index]); // Assumes use after LRU flips on evict
    assign hit_any       = SetA_Hit | SetB_Hit;
    assign sets_word_out = (SetA_Hit) ? SetA_WordOut : SetB_WordOut;
    assign uncacheable   = (CacheAttr_C == 3'b010);  // Not immediately available: Arrives with the physical tag

    DFF_E #(.WIDTH(32))        R_Mem    (.clock(clock), .enable(capture_mem), .D(DataIn_M),      .Q(captured_mem_data));
    DFF_E #(.WIDTH(8))         R_Index  (.clock(clock), .enable(new_read),    .D(index),         .Q(saved_index));
    DFF_E #(.WIDTH(2))         R_Offset (.clock(clock), .enable(new_read),    .D(offset),        .Q(saved_offset));
    DFF_E #(.WIDTH(PABITS-10)) R_STag   (.clock(clock), .enable(new_read),    .D(CacheOpData_C), .Q(saved_stag_data));

    // Common state transition logic to choose the next state when a command is complete.
    // If the processor is stalled the state will not change.
    always @(*) begin
        if (Stall_C) begin
            cmd_or_idle = state;
        end
        else if (DoCacheOp_C) begin
            case (CacheOp_C)
                `CacheOpI_Idx_Inv:  cmd_or_idle = COP_CHECK_IDX_INV;
                `CacheOpI_Idx_STag: cmd_or_idle = COP_CHECK_IDX_STAG;
                `CacheOpI_Adr_HInv: cmd_or_idle = COP_CHECK_ADR_HINV;
                default:            cmd_or_idle = IDLE;
            endcase
        end
        else if (Read_C) begin
            cmd_or_idle = READ_CHECK;
        end
        else begin
            cmd_or_idle = IDLE;
        end
    end

    always @(*) begin
        case (state)
            WAIT_FILL_1:        cmd_select_a = set_select_a;
            WAIT_FILL_2:        cmd_select_a = set_select_a;
            WAIT_FILL_3:        cmd_select_a = set_select_a;
            WAIT_FILL_4:        cmd_select_a = set_select_a;
            COP_CHECK_IDX_INV:  cmd_select_a = PAddressIn_C[0];
            COP_CHECK_IDX_STAG: cmd_select_a = PAddressIn_C[0];
            COP_CHECK_ADR_HINV: cmd_select_a = SetA_Hit;
            default:            cmd_select_a = 1'bx;
        endcase
    end
    always @(*) begin
        new_read = 1'b0;
        if ((Read_C | DoCacheOp_C) & ~Stall_C) begin
            case (state)
                IDLE:               new_read = 1'b1;
                READ_CHECK:         new_read = ~PAddressValid_C | hit_any;
                WAIT_WORD_CPU:      new_read = 1'b1;
                WAIT_LINE_CPU:      new_read = 1'b1;
                COP_CHECK_IDX_INV:  new_read = ~PAddressValid_C;
                COP_CHECK_IDX_STAG: new_read = ~PAddressValid_C;
                COP_CHECK_ADR_HINV: new_read = ~PAddressValid_C;
                WRITE_RECOVER:      new_read = 1'b1;
                default:            new_read = 1'b0;
            endcase
        end
    end
    always @(*) begin
        case (state)
            // cmd_fill_line could possibly just be 'Ready_M'
            WAIT_FILL_1: cmd_fill_line = Ready_M;
            WAIT_FILL_2: cmd_fill_line = Ready_M;
            WAIT_FILL_3: cmd_fill_line = Ready_M;
            WAIT_FILL_4: cmd_fill_line = Ready_M;
            default:     cmd_fill_line = 1'b0;
        endcase
    end
    always @(*) begin
        cmd_inv_line = 1'b0;
        if (PAddressValid_C) begin
            case (state)
                COP_CHECK_IDX_INV:  cmd_inv_line = 1'b1;
                COP_CHECK_ADR_HINV: cmd_inv_line = hit_any;
                default:            cmd_inv_line = 1'b0;
            endcase
        end
    end
    assign cmd_val_line      = (state == WAIT_FILL_4) & Ready_M;
    assign cmd_stag          = (state == COP_CHECK_IDX_STAG) & PAddressValid_C;

    // Cache state machine
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:   next_state = cmd_or_idle;
            READ_CHECK:
                begin
                    if (~PAddressValid_C) begin
                        // TLB miss: Cancel the request / do nothing
                        next_state = cmd_or_idle;
                    end
                    else if (uncacheable) begin
                        // Uncacheable read: Load from memory even if it's in the cache
                        next_state = WAIT_WORD_MEM;
                    end
                    else if (hit_any) begin
                        // Read hit
                        next_state = cmd_or_idle;
                    end
                    else begin
                        // Read miss: Load the cache line from memory
                        next_state = WAIT_FILL_1;
                    end
                end
            WAIT_WORD_MEM:      next_state = (Ready_M) ? WAIT_WORD_CPU : WAIT_WORD_MEM;
            WAIT_FILL_1:        next_state = (Ready_M) ? WAIT_FILL_2 : WAIT_FILL_1;
            WAIT_FILL_2:        next_state = (Ready_M) ? WAIT_FILL_3 : WAIT_FILL_2;
            WAIT_FILL_3:        next_state = (Ready_M) ? WAIT_FILL_4 : WAIT_FILL_3;
            WAIT_FILL_4:        next_state = (Ready_M) ? WAIT_LINE_CPU : WAIT_FILL_4;
            WAIT_WORD_CPU:      next_state = cmd_or_idle;
            WAIT_LINE_CPU:      next_state = cmd_or_idle;
            COP_CHECK_IDX_INV:  next_state = (PAddressValid_C) ? WRITE_RECOVER : cmd_or_idle;
            COP_CHECK_IDX_STAG: next_state = (PAddressValid_C) ? WRITE_RECOVER : cmd_or_idle;
            COP_CHECK_ADR_HINV: next_state = (PAddressValid_C) ? WRITE_RECOVER : cmd_or_idle;
            WRITE_RECOVER:      next_state = cmd_or_idle;
            default:            next_state = IDLE;
        endcase
    end

    DFF_SRE #(.WIDTH(4), .INIT(IDLE)) R_state (.clock(clock), .reset(reset), .enable(1'b1), .D(next_state), .Q(state));

    // Submodule Assignments
    assign SetA_Tag            = PAddressIn_C;
    assign SetA_Index          = (new_read) ? index : saved_index;
    assign SetA_Offset         = (new_read) ? offset : saved_offset;
    assign SetA_LineIndex      = (new_read) ? index : saved_index;
    assign SetA_LineOffset     = DataInOffset_M;
    assign SetA_LineIn         = DataIn_M;
    assign SetA_ValidateLine   = cmd_val_line & cmd_select_a;
    assign SetA_InvalidateLine = cmd_inv_line & cmd_select_a;
    assign SetA_FillLine       = cmd_fill_line & cmd_select_a;
    assign SetA_StoreTag       = cmd_stag & cmd_select_a;
    assign SetA_StoreTagData   = saved_stag_data;
    assign SetB_Tag            = PAddressIn_C;
    assign SetB_Index          = (new_read) ? index : saved_index;
    assign SetB_Offset         = (new_read) ? offset : saved_offset;
    assign SetB_LineIndex      = (new_read) ? index : saved_index;
    assign SetB_LineOffset     = DataInOffset_M;
    assign SetB_LineIn         = DataIn_M;
    assign SetB_ValidateLine   = cmd_val_line & ~cmd_select_a;
    assign SetB_InvalidateLine = cmd_inv_line & ~cmd_select_a;
    assign SetB_FillLine       = cmd_fill_line & ~cmd_select_a;
    assign SetB_StoreTag       = cmd_stag & ~cmd_select_a;
    assign SetB_StoreTagData   = saved_stag_data;

    // LRU Logic: Update the specified line's LRU bit when accessed
    // A value of 0 means B is LRU, and a value of 1 means A is LRU
    integer i;
    initial begin
        // Initialize all to zero (Aids simulation; not necessary for synthesis)
        for (i = 0; i < 256; i = i + 1) begin
            lru[i] = 1'b0;
        end
    end
    always @(posedge clock) begin
        if (reset) begin
            // Reset state doesn't matter in synthesis but helps with simulation
            for (i = 0; i < 256; i = i + 1) begin
                lru[i] <= 1'b0;
            end
        end
        else if (~Stall_C & PAddressValid_C) begin
            if (state == READ_CHECK) begin
                if (SetA_Hit) begin
                    // Read hit on set A
                    lru[saved_index] <= 1'b0;
                end
                else if (SetB_Hit) begin
                    // Read hit on set B
                    lru[saved_index] <= 1'b1;
                end
                else if (~uncacheable) begin
                    // Miss: Eviction causes LRU inversion
                    lru[saved_index] <= ~lru[saved_index];
                end
            end
            else if (state == COP_CHECK_IDX_STAG) begin
                // Cache instruction: Store tag
                lru[saved_index] <= 1'b0; // not implemented
            end
        end
    end

    Set_RO_128x256 #(
        .PABITS          (PABITS))
        Set_A (
        .clock           (clock),
        .reset           (reset),
        .Tag             (SetA_Tag),
        .Index           (SetA_Index),
        .Offset          (SetA_Offset),
        .LineIndex       (SetA_LineIndex),
        .LineOffset      (SetA_LineOffset),
        .WordOut         (SetA_WordOut),
        .Hit             (SetA_Hit),
        .Valid           (SetA_Valid),
        .LineIn          (SetA_LineIn),
        .ValidateLine    (SetA_ValidateLine),
        .InvalidateLine  (SetA_InvalidateLine),
        .FillLine        (SetA_FillLine),
        .StoreTag        (SetA_StoreTag),
        .StoreTagData    (SetA_StoreTagData)
    );

    Set_RO_128x256 #(
        .PABITS          (PABITS))
        Set_B (
        .clock           (clock),
        .reset           (reset),
        .Tag             (SetB_Tag),
        .Index           (SetB_Index),
        .Offset          (SetB_Offset),
        .LineIndex       (SetB_LineIndex),
        .LineOffset      (SetB_LineOffset),
        .WordOut         (SetB_WordOut),
        .Hit             (SetB_Hit),
        .Valid           (SetB_Valid),
        .LineIn          (SetB_LineIn),
        .ValidateLine    (SetB_ValidateLine),
        .InvalidateLine  (SetB_InvalidateLine),
        .FillLine        (SetB_FillLine),
        .StoreTag        (SetB_StoreTag),
        .StoreTagData    (SetB_StoreTagData)
    );

endmodule
