`timescale 1ns / 1ps
/*
 * File         : DataCache_2KB.v
 * Project      : XUM MIPS32 cache enhancement
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   5-Sep-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A data cache for the MIPS32 Release 1 processor core.
 */
module DataCache_2KB #(parameter PABITS=36) (
    input                  clock,
    input                  reset,
    // Processor Interface
    input  [9:0]           VAddressIn_C,    // Bits [11:2]  of the 32-bit virtual address, i.e. the offset of the vpage/pframe.
    input  [(PABITS-13):0] PAddressIn_C,    // Bits [35:12] of the 36-bit physical address, i.e. the TLB-translated physical tag.
    input                  PAddressValid_C, // The physical address is valid (TLB hit).
    input  [2:0]           CacheAttr_C,     // Cache attributes for the requested address.
    input                  Stall_C,
    input  [31:0]          DataIn_C,
    input                  Read_C,
    input  [3:0]           Write_C,
    output [31:0]          DataOut_C,
    output                 Ready_C,
    input                  DoCacheOp_C,     // Synchronous pulse indicating a CACHE operation (i.e. from WB when not stalled).
    input  [2:0]           CacheOp_C,       // Cache operation, encoded in CACHE instruction.
    input  [(PABITS-9):0]  CacheOpData_C,   // Store Tag data (PABITS-9:2->Tag, 1:0->Valid/Dirty).
    // Memory Interface
    output [(PABITS-3):0]  Address_M,       // Physical line (35:4) or word (35:2) address for memory requests.
    output                 ReadLine_M,      // Initiates a cacheline (128-bit) read sequence from memory starting at a word address.
    output                 ReadWord_M,      // Initiates a read for a single 32-bit uncacheable word.
    input  [31:0]          DataIn_M,        // Inbound data from memory.
    input  [1:0]           DataInOffset_M,  // Cacheline word offset (0, 1, 2, or 3) of the incoming data from memory following 'ReadLine_M'.
    output                 LineOutReady_M,  // The cache write buffer is non-empty and 'DataOut_M[127:0]' is valid.
    output                 WordOutReady_M,  // The cache write buffer is non-empty and 'DataOut_M[31:0]' is valid.
    output [3:0]           WordOutBE_M,     // Byte enable bits for single-word memory writes (using 'WordOutReady_M').
    output [127:0]         DataOut_M,       // Writeback data from the cache to memory. Full cacheline ([127:0]) or uncacheable word ([31:0]).
    input                  Ready_M          // 1-cycle pulse indicating one word of valid read data or capture of write data
    );

    `include "../../Core/MIPS_Defines.v"

    /* Cache parameters:
     *   Size: 2 KiB
     *   Block size: 16 bytes
     *   Associativity: 2-way
     */

    /* Supported cache operations:
     *   - CacheOpD_Idx_WbInv:  Index writeback invalidate (000)
     *   - CacheOpD_Idx_STag:   Index store tag (010)
     *   - CacheOpD_Adr_HInv:   Address hit invalidate (100) (TODO)
     *   - CacheOpD_Adr_HWbInv: Address hit writeback invalidate (101)
     *   - CacheOpD_Adr_HWb:    Address hit writeback (110)
     */

    // State encodings
    localparam [3:0] IDLE=0, TAG_CHECK=1, WRITEBACK=2, FILL=3, FILL_WAIT_1=4, FILL_WAIT_2=5,
                     FILL_WAIT_3=6, FILL_WAIT_4=7, FILL_WAIT_WORD=8, WRITE_RECOVER=9, READ_WAIT=10;

    // Local signals
    wire [9:0]  r_vaddr;               // Request virtual address (page/frame offset bits only)
    wire        r_doCacheOp;           // A cache operation request from the processor
    wire [2:0]  r_cacheOp;             // A specific cache operation
    wire [(PABITS-9):0] r_cacheOpData; // Data for the store tag cache operation
    wire        r_read;                // A read request from the processor
    wire [3:0]  r_write;               // A write request from the processor for one or more bytes
    wire        r_write_any;           // A write request from the processor
    wire [31:0] r_write_data;          // Data to be written from the processor to the cache
    wire [5:0]  r_index;               // Request index
    wire [1:0]  r_offset;              // Request offset
    wire [(PABITS-11):0] s_tag;        // TLB-translated physical tag, up to 24 (+2 for 2KB cache) bits of a 36-bit physical address
    wire [(PABITS-11):0] s_index_tag;  // Tag from a given index used for writebacks to memory.
    wire [9:0]  s_vaddr;               // V/P address of the data currently being serviced (page/frame offset bits only)
    wire        s_uncacheable;         // The service address is in the uncacheable range
    wire [31:0] s_uncacheable_data;    // Uncacheable read data that needs to be retained during a stall
    wire        s_read;                // Service stage read command
    wire [3:0]  s_write;               // Service stage write enable/command
    wire        s_write_any;           // Service stage write command
    wire [31:0] s_write_data;          // Service stage write data
    wire        s_doCacheOp;           // Cache instruction
    wire [2:0]  s_cacheOp;             // Cache instruction function
    wire [(PABITS-9):0] s_cacheOpData; // Cache instruction store tag data
    wire        s_cacheOp_sel_a;       // The cache instruction index address selects set A
    wire        s_valid_a_e;           // Set A is valid for the prior request (ephemeral)
    wire        s_valid_b_e;           // Set B is valid for the prior request (ephemeral)
    wire        s_hit_a_e;             // Set A hit for the prior request (ephemeral)
    wire        s_hit_b_e;             // Set B hit for the prior request (ephemeral)
    wire        s_hit_e;               // Cache hit for prior request (ephemeral)
    wire        s_hit_d;               // Cache hit for prior request (delay)
    wire        s_hit;                 // Authoritative hit signal for a prior request
    wire [31:0] s_hit_data_e;          // Cache read data (ephemeral)
    wire        s_dirty_a_e;           // Set A is dirty for the prior request (ephemeral)
    wire        s_dirty_b_e;           // Set B is dirty for the prior request (ephemeral)
    wire        s_evict_e;             // The requested address must first evict a cacheline (ephemeral)
    wire        s_dirty_evict_e;       // The requested address must first writeback then evict a cacheline (ephemeral)
    wire        s_set_select_a_e;      // Set A is selected for a fill or evict-then-fill
    wire [31:0] s_hit_data_d;          // Cache read data (delay)
    wire        s_valid_a_d;           // Set B is valid for the prior request (delay)
    wire        s_valid_b_d;           // Set B is valid for the prior request (delay)
    wire        s_hit_a_d;             // Set A hit for the prior request (delay)
    wire        s_hit_b_d;             // Set B hit for the prior request (delay)
    wire        s_evict_d;             // The requested address must first evict a cacheline (delay)
    wire        s_set_select_a_d;      // TODO: Basically a fill select (evict, fill)
    wire        using_delay_data;      // The service stage has stalled and requires latched data from the request stage
    wire        delay_update;          // Indicates that the service data delay registers should capture
    wire        cond_wb_idx_wbinv;     // Shorthand signal for an index writeback invalidate condition
    wire        cond_wb_adr_hwb;       // Shorthand signal for an address hit writeback condition
    wire        cond_tagcheck_remain;  // Shorthand signal for remaining in the TAG_CHECK state or idling
    reg         lru [0:63];            // Least-recently used Set (1->A, 0->B)
    reg         new_request;           // The cache is beginning a new request (non-cacheop)
    reg         new_request_r;         // A one-clock delay signal of a new pipeline request
    reg         pseudo_new_request_r;  // An 're-request' delay signal following a fill
    wire        new_reqs_r;            // The OR of new_requests and restarted requests
    reg         ready;                 // Ready signal to the processor; the request is complete
    reg  [3:0]  state;                 // Cache state

    // Set signals
    wire [(PABITS-11):0] SetA_Tag,            SetB_Tag;
    wire [5:0]           SetA_Index,          SetB_Index;
    wire [1:0]           SetA_Offset,         SetB_Offset;
    wire [5:0]           SetA_LineIndex,      SetB_LineIndex;
    wire [1:0]           SetA_LineOffset,     SetB_LineOffset;
    wire [31:0]          SetA_WordIn,         SetB_WordIn;
    wire [31:0]          SetA_WordOut,        SetB_WordOut;
    wire                 SetA_Hit,            SetB_Hit;
    wire                 SetA_Valid,          SetB_Valid;
    wire                 SetA_Dirty,          SetB_Dirty;
    wire [(PABITS-11):0] SetA_IndexTag,       SetB_IndexTag;
    wire [31:0]          SetA_LineIn,         SetB_LineIn;
    wire [127:0]         SetA_LineOut,        SetB_LineOut;
    wire [3:0]           SetA_WriteWord,      SetB_WriteWord;
    wire                 SetA_ValidateLine,   SetB_ValidateLine;
    reg                  SetA_InvalidateLine, SetB_InvalidateLine;
    wire                 SetA_FillLine,       SetB_FillLine;
    wire                 SetA_StoreTag,       SetB_StoreTag;
    wire [(PABITS-9):0]  SetA_StoreTagData,   SetB_StoreTagData;

    // Write buffer signals
    wire WB_EnQ;
    wire WB_DeQ;
    wire WB_Empty;
    wire WB_Full;
    reg  [((PABITS-5)+129):0] WB_DataIn;    // {32-bit line addr, 128-bit line, 1-bit cacheable} OR
    wire [((PABITS-5)+129):0] WB_DataOut;   // {34-bit word addr, 90-bit X, 4-bit write-enable, 32-bit word, 1-bit uncacheable}

    /**** Assignments ****/

    // Top-level assignments
    assign DataOut_C      = (state == FILL_WAIT_WORD) ? s_uncacheable_data : ((using_delay_data) ? s_hit_data_d : s_hit_data_e);
    assign Ready_C        = ready;
    assign Address_M      = (WB_Empty) ? {s_tag, s_vaddr[7:0]} : WB_DataOut[((PABITS-5)+129):127];
    assign ReadLine_M     = (state == FILL) & WB_Empty & ~s_uncacheable;
    assign ReadWord_M     = (state == FILL) & WB_Empty &  s_uncacheable;
    assign LineOutReady_M = ~WB_Empty &  WB_DataOut[0];
    assign WordOutReady_M = ~WB_Empty & ~WB_DataOut[0];
    assign WordOutBE_M    = WB_DataOut[36:33];
    assign DataOut_M      = WB_DataOut[128:1];

    // Set assignments
    assign SetA_Tag            = s_tag;
    assign SetA_Index          = r_index;
    assign SetA_Offset         = r_offset;
    assign SetA_LineIndex      = r_index;
    assign SetA_LineOffset     = DataInOffset_M;
    assign SetA_WordIn         = s_write_data;
    assign SetA_LineIn         = DataIn_M;
    assign SetA_WriteWord      = (PAddressValid_C & s_hit_a_e & ((state == TAG_CHECK) | ((state == FILL_WAIT_4) & Ready_M & s_write_any))) ? s_write : 4'h0;
    assign SetA_ValidateLine   = (state == FILL_WAIT_4) & Ready_M & s_set_select_a_d;
    assign SetA_FillLine       = &{Ready_M, WB_Empty, s_set_select_a_d, ~s_uncacheable};
    assign SetA_StoreTag       = (state == TAG_CHECK) & PAddressValid_C & s_doCacheOp & (s_cacheOp == `CacheOpD_Idx_STag) & s_cacheOp_sel_a;
    assign SetA_StoreTagData   = s_cacheOpData;
    assign SetB_Tag            = s_tag;
    assign SetB_Index          = r_index;
    assign SetB_Offset         = r_offset;
    assign SetB_LineIndex      = r_index;
    assign SetB_LineOffset     = DataInOffset_M;
    assign SetB_WordIn         = s_write_data;
    assign SetB_LineIn         = DataIn_M;
    assign SetB_WriteWord      = (PAddressValid_C & s_hit_b_e & ((state == TAG_CHECK) | ((state == FILL_WAIT_4) & Ready_M & s_write_any))) ? s_write : 4'h0;
    assign SetB_ValidateLine   = (state == FILL_WAIT_4) & Ready_M & ~s_set_select_a_d;
    assign SetB_FillLine       = &{Ready_M, WB_Empty, ~s_set_select_a_d, ~s_uncacheable};
    assign SetB_StoreTag       = (state == TAG_CHECK) & PAddressValid_C & s_doCacheOp & (s_cacheOp == `CacheOpD_Idx_STag) & ~s_cacheOp_sel_a;
    assign SetB_StoreTagData   = s_cacheOpData;

    // Set line invalidation
    always @(*) begin
        if (~PAddressValid_C) begin
            SetA_InvalidateLine <= 1'b0;
            SetB_InvalidateLine <= 1'b0;
        end
        else if (s_doCacheOp) begin
            case (state)
                TAG_CHECK:
                    begin
                        if (s_doCacheOp) begin
                            case (s_cacheOp)
                                // XXX TODO: Do these need delayed hit inputs too?
                                `CacheOpD_Idx_WbInv:
                                    begin
                                        SetA_InvalidateLine <= (s_cacheOp_sel_a  & s_valid_a_e & ~s_dirty_a_e);
                                        SetB_InvalidateLine <= (~s_cacheOp_sel_a & s_valid_b_e & ~s_dirty_b_e);
                                    end
                                `CacheOpD_Adr_HInv:
                                    begin
                                        SetA_InvalidateLine <= s_hit_a_e;
                                        SetB_InvalidateLine <= s_hit_b_e;
                                    end
                                `CacheOpD_Adr_HWbInv:
                                    begin
                                        SetA_InvalidateLine <= (s_hit_a_e & ~s_dirty_a_e);
                                        SetB_InvalidateLine <= (s_hit_b_e & ~s_dirty_b_e);
                                    end
                                default:
                                    begin
                                        SetA_InvalidateLine <= 1'b0;
                                        SetB_InvalidateLine <= 1'b0;
                                    end
                            endcase
                        end
                        else begin
                            SetA_InvalidateLine <= 1'b0;
                            SetB_InvalidateLine <= 1'b0;
                        end
                    end
                WRITEBACK:
                    begin
                        case (s_cacheOp)
                            `CacheOpD_Idx_WbInv:
                                begin
                                    SetA_InvalidateLine <= s_cacheOp_sel_a  & s_valid_a_d;
                                    SetB_InvalidateLine <= ~s_cacheOp_sel_a & s_valid_b_d;
                                end
                            `CacheOpD_Adr_HWbInv:
                                begin
                                    SetA_InvalidateLine <= s_hit_a_d;
                                    SetB_InvalidateLine <= s_hit_b_d;
                                end
                            default:
                                begin
                                    SetA_InvalidateLine <= 1'b0;
                                    SetB_InvalidateLine <= 1'b0;
                                end
                        endcase
                    end
                default:
                    begin
                        SetA_InvalidateLine <= 1'b0;
                        SetB_InvalidateLine <= 1'b0;
                    end
            endcase
        end
        else begin
            SetA_InvalidateLine <= 1'b0;
            SetB_InvalidateLine <= 1'b0;
        end
    end

    // Write buffer assignments
    assign WB_EnQ    = (state == WRITEBACK) & ~WB_Full;
    assign WB_DeQ    = ~WB_Empty & Ready_M;

    // All writebacks from the cache use the cache's tag instead of the processor-supplied tag. The
    // only exception to this is uncacheable writes where the processor has the only tag information.
    always @(*) begin
        // {la[160:129], line[128:1], cached[0]} OR
        // {wa[160:127], X[126:37], we[36:33], data[32:1], cached[0]}
        WB_DataIn[((PABITS-5)+129):129] <= (s_uncacheable & ~s_doCacheOp) ? {s_tag, s_vaddr[7:2]} : {s_index_tag, s_vaddr[7:2]};
        if (s_doCacheOp) begin
            case (s_cacheOp)
                `CacheOpD_Idx_WbInv:    WB_DataIn[128:1] <= (s_cacheOp_sel_a) ? SetA_LineOut : SetB_LineOut;
                `CacheOpD_Adr_HWbInv:   WB_DataIn[128:1] <= (s_hit_a_d) ? SetA_LineOut : SetB_LineOut;
                `CacheOpD_Adr_HWb:      WB_DataIn[128:1] <= (s_hit_a_d) ? SetA_LineOut : SetB_LineOut;
                default:                WB_DataIn[128:1] <= {128{1'bx}};
            endcase
            WB_DataIn[0] <= 1'b1;
        end
        else if (s_uncacheable) begin
            WB_DataIn[128:127] <= s_vaddr[1:0];
            WB_DataIn[126:37]  <= {90{1'bx}};
            WB_DataIn[36:33]   <= s_write;
            WB_DataIn[32:1]    <= s_write_data;
            WB_DataIn[0]       <= 1'b0;
        end
        else begin
            WB_DataIn[128:1] <= (s_set_select_a_d) ? SetA_LineOut : SetB_LineOut;
            WB_DataIn[0]     <= 1'b1;
        end
    end

    // Local assignments
    assign r_vaddr          = VAddressIn_C;
    assign r_doCacheOp      = DoCacheOp_C;
    assign r_cacheOp        = CacheOp_C;
    assign r_cacheOpData    = CacheOpData_C;
    assign r_read           = Read_C;
    assign r_write          = Write_C;
    assign r_write_any      = (r_write != 4'b0000);
    assign r_write_data     = DataIn_C;
    assign r_index          = (new_request) ? r_vaddr[7:2] : s_vaddr[7:2];
    assign r_offset         = (new_request) ? r_vaddr[1:0] : s_vaddr[1:0];
    assign s_tag            = {PAddressIn_C, s_vaddr[9:8]}; // Use part of the virtual index for this small cache.
    assign s_uncacheable    = (CacheAttr_C == 3'b010);
    assign s_write_any      = (s_write != 4'b0000);
    assign s_cacheOp_sel_a  = s_tag[0];     // Corresponds to address bit 10 (one bit higher than index bits)
    assign s_valid_a_e      = SetA_Valid;
    assign s_valid_b_e      = SetB_Valid;
    assign s_hit_a_e        = SetA_Hit;
    assign s_hit_b_e        = SetB_Hit;
    assign s_hit_e          = SetA_Hit | SetB_Hit;
    assign s_hit_d          = s_hit_a_d | s_hit_b_d;
    assign s_hit            = (using_delay_data) ? s_hit_d : s_hit_e;
    assign s_hit_data_e     = (SetA_Hit) ? SetA_WordOut : SetB_WordOut;
    assign s_dirty_a_e      = SetA_Dirty;
    assign s_dirty_b_e      = SetB_Dirty;
    assign s_evict_e        = SetA_Valid & ~SetA_Hit & SetB_Valid & ~SetB_Hit;
    assign s_dirty_evict_e  = s_evict_e & ((lru[s_vaddr[7:2]] & SetA_Dirty) | (~lru[s_vaddr[7:2]] & SetB_Dirty));
    assign s_set_select_a_e = ~SetA_Valid | (s_evict_e & lru[s_vaddr[7:2]]);
    assign delay_update     = ~new_request & (state == TAG_CHECK);
    assign new_reqs_r       = new_request_r | pseudo_new_request_r;

    // The pipeline registers between request (r) and service (s) stages
    DFF_SRE #(.WIDTH(1)) ff_s_read      (.clock(clock), .reset(reset), .enable(new_request), .D(r_read),      .Q(s_read));
    DFF_SRE #(.WIDTH(4)) ff_s_write     (.clock(clock), .reset(reset), .enable(new_request), .D(r_write),     .Q(s_write));
    DFF_SRE #(.WIDTH(1)) ff_s_DoCacheOp (.clock(clock), .reset(reset), .enable(new_request), .D(r_doCacheOp), .Q(s_doCacheOp));
    DFF_E #(.WIDTH(10))       ff_s_vaddr          (.clock(clock), .enable(new_request),   .D(r_vaddr),          .Q(s_vaddr));
    DFF_E #(.WIDTH(32))       ff_s_write_data     (.clock(clock), .enable(new_request),   .D(r_write_data),     .Q(s_write_data));
    DFF_E #(.WIDTH(3))        ff_s_cacheOp        (.clock(clock), .enable(new_request),   .D(r_cacheOp),        .Q(s_cacheOp));
    DFF_E #(.WIDTH(PABITS-8)) ff_s_cacheOpData    (.clock(clock), .enable(new_request),   .D(r_cacheOpData),    .Q(s_cacheOpData));
    DFF_E #(.WIDTH(1))        ff_s_valid_a_d      (.clock(clock), .enable(new_request_r), .D(s_valid_a_e),      .Q(s_valid_a_d));
    DFF_E #(.WIDTH(1))        ff_s_valid_b_d      (.clock(clock), .enable(new_request_r), .D(s_valid_b_e),      .Q(s_valid_b_d));
    DFF_E #(.WIDTH(1))        ff_s_hit_a_d        (.clock(clock), .enable(new_request_r), .D(s_hit_a_e),        .Q(s_hit_a_d));
    DFF_E #(.WIDTH(1))        ff_s_hit_b_d        (.clock(clock), .enable(new_request_r), .D(s_hit_b_e),        .Q(s_hit_b_d));
    DFF_E #(.WIDTH(1))        ff_s_evict_d        (.clock(clock), .enable(new_request_r), .D(s_evict_e),        .Q(s_evict_d));
    DFF_E #(.WIDTH(1))        ff_s_set_select_a_d (.clock(clock), .enable(new_request_r), .D(s_set_select_a_e), .Q(s_set_select_a_d));
    DFF_E #(.WIDTH(32))       ff_s_hit_data_d     (.clock(clock), .enable(new_reqs_r),    .D(s_hit_data_e),     .Q(s_hit_data_d));
    DFF_E #(.WIDTH(1))        ff_using_delay_data (.clock(clock), .enable(1'b1),          .D(delay_update),     .Q(using_delay_data));

    // Uncacheable read data capture
    DFF_E #(.WIDTH(32)) ff_s_uncacheable_data (.clock(clock), .enable((state == FILL_WAIT_1)), .D(DataIn_M), .Q(s_uncacheable_data));

    // Writeback tag capture
    reg [(PABITS-11):0] s_index_tag_in;
    always @(*) begin
        if (state == TAG_CHECK) begin
            if (s_doCacheOp) begin
                case (s_cacheOp)
                    `CacheOpD_Idx_WbInv:    s_index_tag_in <= (s_cacheOp_sel_a) ? SetA_IndexTag : SetB_IndexTag;
                    default:                s_index_tag_in <= (s_hit_a_e) ? SetA_IndexTag : SetB_IndexTag;
                endcase
            end
            else begin
                s_index_tag_in <= (s_set_select_a_e) ? SetA_IndexTag : SetB_IndexTag;
            end
        end
        else begin
            s_index_tag_in <= {PABITS-10{1'bx}};
        end
    end
    DFF_E #(.WIDTH(PABITS-10)) ff_s_index_tag (.clock(clock), .enable((state == TAG_CHECK)), .D(s_index_tag_in), .Q(s_index_tag));

    // Shorthand signal aliases
    assign cond_wb_idx_wbinv    = (s_cacheOp_sel_a & s_valid_a_e & s_dirty_a_e) | (~s_cacheOp_sel_a & s_valid_b_e & s_dirty_b_e);
    assign cond_wb_adr_hwb      = (s_hit_a_e & s_dirty_a_e) | (s_hit_b_e & s_dirty_b_e);
    assign cond_tagcheck_remain = Stall_C | r_read | r_write_any | r_doCacheOp;

    // The signal 'new_request' indicates when the pipeline advances for a new request
    always @(*) begin
        if (~Stall_C & (r_read | r_write_any | r_doCacheOp)) begin
            case (state)
                IDLE:           new_request <= 1'b1;
                TAG_CHECK:
                    begin
                        if (~PAddressValid_C) begin
                            new_request <= 1'b1;
                        end
                        else if (s_doCacheOp) begin
                            case (s_cacheOp)
                                `CacheOpD_Idx_WbInv:    new_request <= 1'b0;
                                `CacheOpD_Adr_HInv:     new_request <= 1'b0;
                                `CacheOpD_Adr_HWbInv:   new_request <= 1'b0;
                                `CacheOpD_Adr_HWb:      new_request <= 1'b0;
                                default:                new_request <= 1'b0;
                            endcase
                        end
                        else begin
                            new_request <= s_hit & ~s_write_any;
                        end
                    end
                WRITE_RECOVER:  new_request <= 1'b1;
                WRITEBACK:      new_request <= ~WB_Full & ~s_doCacheOp & s_uncacheable;
                FILL_WAIT_WORD: new_request <= 1'b1;
                READ_WAIT:      new_request <= 1'b1;
                default:        new_request <= 1'b0;
            endcase
        end
        else begin
            new_request <= 1'b0;
        end
    end

    // One cycle delay of a new request
    always @(posedge clock) begin
        new_request_r <= (reset) ? 1'b0 : new_request;
    end

    // A re-request after a fill
    always @(posedge clock) begin
        pseudo_new_request_r <= (reset) ? 1'b0 : ((state == FILL_WAIT_4) & Ready_M);
    end

    // Ready signal to the processor
    always @(*) begin
        case (state)
            TAG_CHECK:
                begin
                    if (~PAddressValid_C) begin
                        ready <= 1'b1;
                    end
                    else if (s_doCacheOp) begin
                        case (s_cacheOp)
                            `CacheOpD_Idx_WbInv:    ready <= 1'b0;
                            `CacheOpD_Adr_HInv:     ready <= 1'b0;
                            `CacheOpD_Adr_HWbInv:   ready <= 1'b0;
                            `CacheOpD_Adr_HWb:      ready <= 1'b0;
                            default:                ready <= 1'b0;
                        endcase
                    end
                    else begin
                        ready <= s_hit & ~s_uncacheable & ~s_write_any; // Assumes stalls hold CacheAttr_C
                    end
                end
            WRITE_RECOVER:  ready <= 1'b1;
            WRITEBACK:      ready <= ~WB_Full & ~s_doCacheOp & s_uncacheable;
            FILL_WAIT_WORD: ready <= 1'b1;
            READ_WAIT:      ready <= 1'b1;
            default:        ready <= 1'b0;
        endcase
    end

    // Cache state machine
    always @(posedge clock) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE:
                    begin
                        state <= (Stall_C | ~(r_read | r_write_any | r_doCacheOp)) ? IDLE : TAG_CHECK;
                    end
                TAG_CHECK:
                    begin
                        if (~PAddressValid_C) begin
                            // TLB miss, flush; do nothing
                            state <= (cond_tagcheck_remain) ? TAG_CHECK : IDLE;
                        end
                        else if (s_doCacheOp) begin
                            case (s_cacheOp)
                                `CacheOpD_Idx_WbInv:
                                    begin
                                        state <= (cond_wb_idx_wbinv) ? WRITEBACK : WRITE_RECOVER;
                                    end
                                `CacheOpD_Idx_STag:
                                    begin
                                        state <= WRITE_RECOVER;
                                    end
                                `CacheOpD_Adr_HInv:
                                    begin
                                        state <= WRITE_RECOVER;
                                    end
                                `CacheOpD_Adr_HWbInv:
                                    begin
                                        state <= (cond_wb_adr_hwb) ? WRITEBACK : WRITE_RECOVER;
                                    end
                                `CacheOpD_Adr_HWb:
                                    begin
                                        state <= (cond_wb_adr_hwb) ? WRITEBACK : WRITE_RECOVER;
                                    end
                                default:
                                    begin
                                        state <= WRITE_RECOVER;
                                    end
                            endcase
                        end
                        else begin
                            if (s_uncacheable) begin
                                // Uncacheable Read/Write
                                state <= (s_read) ? FILL : WRITEBACK;
                            end
                            else if (s_hit) begin
                                // Read/Write hit
                                state <= (s_write_any) ? WRITE_RECOVER : ((cond_tagcheck_remain) ? TAG_CHECK : IDLE);
                            end
                            else if (s_dirty_evict_e) begin
                                // Read/Write miss; dirty data
                                state <= WRITEBACK;
                            end
                            else begin
                                // Read/Write miss; clean/invalid data
                                state <= FILL;
                            end
                        end
                    end
                WRITE_RECOVER:
                    begin
                        state <= (Stall_C) ? WRITE_RECOVER : ((r_read | r_write_any | r_doCacheOp) ? TAG_CHECK : IDLE);
                    end
                WRITEBACK:
                    begin
                        if (WB_Full) begin
                            // Wait if the write buffer is full
                            state <= WRITEBACK;
                        end
                        else if (s_doCacheOp) begin
                            // CacheOp writeback-then-invalidate or standalone writeback
                            state <= WRITE_RECOVER;
                        end
                        else if (s_uncacheable) begin
                            // Uncacheable write
                            state <= (Stall_C) ? WRITEBACK : ((r_read | r_write_any | r_doCacheOp) ? TAG_CHECK : IDLE);
                        end
                        else begin
                            // Cacheable writeback-then-fill (assumed s_read | s_write_any)
                            state <= FILL;
                        end
                    end
                FILL:
                    begin
                        state <= (WB_Empty) ? FILL_WAIT_1 : FILL;
                    end
                FILL_WAIT_1:
                    begin
                        state <= (Ready_M) ? ((s_uncacheable) ? FILL_WAIT_WORD : FILL_WAIT_2) : FILL_WAIT_1;
                    end
                FILL_WAIT_2:
                    begin
                        state <= (Ready_M) ? FILL_WAIT_3 : FILL_WAIT_2;
                    end
                FILL_WAIT_3:
                    begin
                        state <= (Ready_M) ? FILL_WAIT_4 : FILL_WAIT_3;
                    end
                FILL_WAIT_4:
                    // TODO this state can be optimized for writes
                    begin
                        // We can't go directly to TAG_CHECK if the core is stalled since it will initiate a new read
                        state <= (Ready_M) ? ((Stall_C) ? READ_WAIT : TAG_CHECK) : FILL_WAIT_4;
                    end
                READ_WAIT:
                    begin
                        // A holding state when fills are done but the core is stalled. Prevents extra fills
                        state <= (Stall_C) ? READ_WAIT : ((r_read | r_write_any | r_doCacheOp) ? TAG_CHECK : IDLE);
                    end
                FILL_WAIT_WORD:
                    begin
                        state <= (Stall_C) ? FILL_WAIT_WORD : ((r_read | r_write_any | r_doCacheOp) ? TAG_CHECK : IDLE);
                    end
                default:
                    begin
                        state <= IDLE;
                    end
            endcase
        end
    end

    // LRU Logic : Update the specified line's LRU bit when accessed
    integer i;
    initial begin
        // Initialize all to zero
        for (i=0; i<64; i=i+1) begin
            lru[i] <= 1'b0;
        end
    end
    always @(posedge clock) begin
        if (reset) begin
            // Reset state doesn't matter in synthesis but helps with simulation
            for (i=0; i<64; i=i+1) begin
                lru[i] <= 1'b0;
            end
        end
        else if ((state == TAG_CHECK) & ~Stall_C & PAddressValid_C) begin
            if (s_doCacheOp & (s_cacheOp == `CacheOpD_Idx_STag)) begin
                // Cache instruction: Store tag
                lru[s_vaddr[7:2]] <= 1'b0; // not implemented
            end
            else if ((using_delay_data & s_evict_d) | (~using_delay_data & s_evict_e)) begin
                // Evict
                lru[s_vaddr[7:2]] <= ~lru[s_vaddr[7:2]];
            end
            else if ((using_delay_data & s_hit_a_d) | (~using_delay_data & s_hit_a_e)) begin
                // Read or write hit on set A
                lru[s_vaddr[7:2]] <= 1'b0;
            end
            else if ((using_delay_data & s_hit_b_d) | (~using_delay_data & s_hit_b_e)) begin
                // Read or Write hit on set B
                lru[s_vaddr[7:2]] <= 1'b1;
            end
            else begin
                lru[s_vaddr[7:2]] <= lru[s_vaddr[7:2]];
            end
        end
        else begin
            lru[s_vaddr[7:2]] <= lru[s_vaddr[7:2]];
        end
    end

    Set_RW_128x64 #(
        .PABITS          (PABITS))
        Set_A (
        .clock           (clock),
        .reset           (reset),
        .Tag             (SetA_Tag),
        .Index           (SetA_Index),
        .Offset          (SetA_Offset),
        .LineIndex       (SetA_LineIndex),
        .LineOffset      (SetA_LineOffset),
        .WordIn          (SetA_WordIn),
        .WordOut         (SetA_WordOut),
        .Hit             (SetA_Hit),
        .Valid           (SetA_Valid),
        .Dirty           (SetA_Dirty),
        .IndexTag        (SetA_IndexTag),
        .LineIn          (SetA_LineIn),
        .LineOut         (SetA_LineOut),
        .WriteWord       (SetA_WriteWord),
        .ValidateLine    (SetA_ValidateLine),
        .InvalidateLine  (SetA_InvalidateLine),
        .FillLine        (SetA_FillLine),
        .StoreTag        (SetA_StoreTag),
        .StoreTagData    (SetA_StoreTagData)
    );

    Set_RW_128x64 #(
        .PABITS          (PABITS))
        Set_B (
        .clock           (clock),
        .reset           (reset),
        .Tag             (SetB_Tag),
        .Index           (SetB_Index),
        .Offset          (SetB_Offset),
        .LineIndex       (SetB_LineIndex),
        .LineOffset      (SetB_LineOffset),
        .WordIn          (SetB_WordIn),
        .WordOut         (SetB_WordOut),
        .Hit             (SetB_Hit),
        .Valid           (SetB_Valid),
        .Dirty           (SetB_Dirty),
        .IndexTag        (SetB_IndexTag),
        .LineIn          (SetB_LineIn),
        .LineOut         (SetB_LineOut),
        .WriteWord       (SetB_WriteWord),
        .ValidateLine    (SetB_ValidateLine),
        .InvalidateLine  (SetB_InvalidateLine),
        .FillLine        (SetB_FillLine),
        .StoreTag        (SetB_StoreTag),
        .StoreTagData    (SetB_StoreTagData)
    );

    // The FIFO normally holds the line address and line data.
    // However, uncacheable writes form a word address,
    // byte-enable bits, and word data.
    FIFO #(
        .DATA_WIDTH  (((PABITS-5)+129+1)),
        .ADDR_WIDTH  (2))
        WriteBuffer (
        .clock     (clock),
        .reset     (reset),
        .enQ       (WB_EnQ),
        .deQ       (WB_DeQ),
        .data_in   (WB_DataIn),
        .data_out  (WB_DataOut),
        .empty     (WB_Empty),
        .full      (WB_Full)
    );

endmodule

