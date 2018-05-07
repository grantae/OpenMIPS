`timescale 1ns / 1ps
/*
 * File         : DSP_MAddSub_32x32x64.v
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
 *   A multi-cycle 64-bit hardware multiply-adder/multiply-subtractor
 *   using Xilinx DSP48A1 resources.
 *
 *   Results are available either on the 6th (multiply only) or 8th
 *   (fused multiply/add or multiply/subtract) rising clock edge after
 *   the 'start' signal is asserted. At this time 'busy' will be low.
 *
 *   Operations can be interrupted by asserting the 'start' signal at
 *   any time.
 */
module DSP_MAddSub_32x32x64(
    input         clock,
    input         reset,
    input  [31:0] A,        // First multiplicand
    input  [31:0] B,        // Second multiplicand
    input  [63:0] C,        // Addend (C + (A*B)) or minuend (C - (A*B))
    input         sign,     // Treat inputs as signed (1) or unsigned (0)
    input         fused,    // Perform a fused multiply/add or multiply/subtract
    input         subtract, // Select between addition or subtraction for fused computations
    input         start,    // Begin a computation
    output reg    busy,     // A computation is in progress
    output [64:0] D         // Result
    );

    localparam [3:0] IDLE=0, M1=1, M2=2, M3=3, M4=4, M5=5, M6=6, F1=7, F2=8;

    // Local state and signals
    reg [3:0] state;
    reg sign_r;
    reg fused_r;
    reg subtract_r;

    // Register clock enables (multiplier)
    wire BLAL_CEA, BLAH_CEA, BHAL_CEA, BHAH_CEA;
    wire BLAL_CEB, BLAH_CEB, BHAL_CEB, BHAH_CEB;
    wire BLAL_CEM, BLAH_CEM, BHAL_CEM, BHAH_CEM;
    wire BLAL_CEP, BLAH_CEP, BHAL_CEP, BHAH_CEP;

    // Register clock enables (addsub)
    wire Lo_CEA, Lo_CEB, Lo_CEC, Lo_CED, Lo_CEP, Lo_CEOPMODE;
    wire         Hi_CEB, Hi_CEC,         Hi_CEP, Hi_CEOPMODE;

    // Datapath signals (multiplier)
    wire [17:0] BLAL_BCOUT, BHAL_BCOUT;
    wire [47:0] BLAL_P, BLAH_P, BHAL_P;
    wire [31:0] BHAH_P;
    wire [63:0] Product;
    wire [64:0] Sum;

    // Datapath signals (addsub)
    wire        Lo_CARRYOUT;
    wire [47:0] Lo_S;
    wire [16:0] Hi_S;

    // Assignments
    assign Product[63:32] = BHAH_P;
    assign Product[31:16] = BHAL_P[15:0];
    assign Product[15:0]  = BLAL_P[15:0];
    assign Sum            = {Hi_S, Lo_S};

    always @(posedge clock) begin
        if (start) begin
            sign_r     <= sign;
            fused_r    <= fused;
            subtract_r <= subtract;
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            state <= IDLE;
        end
        else if (start) begin
            state <= M1;
        end
        else begin
            case (state)
                IDLE:    state <= IDLE;
                M1:      state <= M2;
                M2:      state <= M3;
                M3:      state <= M4;
                M4:      state <= M5;
                M5:      state <= M6;
                M6:      state <= (fused_r) ? F1 : IDLE;
                F1:      state <= F2;
                F2:      state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE:    busy <= 1'b0;
            M1:      busy <= 1'b1;
            M2:      busy <= 1'b1;
            M3:      busy <= 1'b1;
            M4:      busy <= 1'b1;
            M5:      busy <= 1'b1;
            M6:      busy <= fused_r;
            F1:      busy <= 1'b1;
            F2:      busy <= 1'b0;
            default: busy <= 1'bx;
        endcase
    end

    assign D = (fused_r) ? Sum : {1'b0, Product};

    assign BLAL_CEA    = start;
    assign BLAH_CEA    = start;
    assign BHAL_CEA    = start;
    assign BHAH_CEA    = start;
    assign BLAL_CEB    = start;
    assign BLAH_CEB    = (state == M1);
    assign BHAL_CEB    = start;
    assign BHAH_CEB    = (state == M1);
    assign BLAL_CEM    = 1'b1;
    assign BLAH_CEM    = 1'b1;
    assign BHAL_CEM    = 1'b1;
    assign BHAH_CEM    = 1'b1;
    assign BLAL_CEP    = (state == M2);
    assign BLAH_CEP    = (state == M3);
    assign BHAL_CEP    = (state == M4);
    assign BHAH_CEP    = (state == M5);
    assign Lo_CEA      = (state == M6);
    assign Lo_CEB      = (state == M6);
    assign Lo_CEC      = (state == M6);
    assign Lo_CED      = (state == M6);
    assign Lo_CEP      = (state == F1);
    assign Lo_CEOPMODE = (state == M6);
    assign Hi_CEB      = (state == M6);
    assign Hi_CEC      = (state == M6);
    assign Hi_CEP      = (state == F1);
    assign Hi_CEOPMODE = (state == M6);

    // Multiplier BLAL
    DSP_Mult_32x32_BLAL BLAL (
        .clock  (clock),
        .reset  (reset),
        .AL     (A[15:0]),
        .BL     (B[15:0]),
        .CEA    (BLAL_CEA),
        .CEB    (BLAL_CEB),
        .CEM    (BLAL_CEM),
        .CEP    (BLAL_CEP),
        .BCOUT  (BLAL_BCOUT),
        .P      (BLAL_P)
    );

    // Multiplier BLAH
    DSP_Mult_32x32_BLAH BLAH (
        .clock    (clock),
        .reset    (reset),
        .sign     (sign),
        .AH       (A[31:16]),
        .BCIN     (BLAL_BCOUT),
        .C_shift  ({{16{1'b0}}, BLAL_P[47:16]}),
        .CEA      (BLAH_CEA),
        .CEB      (BLAH_CEB),
        .CEM      (BLAH_CEM),
        .CEP      (BLAH_CEP),
        .P        (BLAH_P)
    );

    // Multiplier BHAL
    DSP_Mult_32x32_BHAL BHAL (
        .clock  (clock),
        .reset  (reset),
        .sign   (sign),
        .AL     (A[15:0]),
        .BH     (B[31:16]),
        .C      (BLAH_P),
        .CEA    (BHAL_CEA),
        .CEB    (BHAL_CEB),
        .CEM    (BHAL_CEM),
        .CEP    (BHAL_CEP),
        .BCOUT  (BHAL_BCOUT),
        .P      (BHAL_P)
    );

    // Multiplier BHAH
    DSP_Mult_32x32_BHAH BHAH (
        .clock    (clock),
        .reset    (reset),
        .sign     (sign),
        .AH       (A[31:16]),
        .BCIN     (BHAL_BCOUT),
        .C_shift  ({{16{1'b0}}, BHAL_P[47:16]}),
        .CEA      (BHAH_CEA),
        .CEB      (BHAH_CEB),
        .CEM      (BHAH_CEM),
        .CEP      (BHAH_CEP),
        .P        (BHAH_P)
    );

    // AddSub low bits
    DSP_AddSub_64x64_Low Low (
        .clock     (clock),
        .subtract  (subtract_r),
        .A_Low     (C[47:0]),
        .B_Low     (Product[47:0]),
        .CEA       (Lo_CEA),
        .CEB       (Lo_CEB),
        .CEC       (Lo_CEC),
        .CED       (Lo_CED),
        .CEP       (Lo_CEP),
        .CEOPMODE  (Lo_CEOPMODE),
        .CARRYOUT  (Lo_CARRYOUT),
        .S         (Lo_S)
    );

    // AddSub high bits
    DSP_AddSub_64x64_High High (
        .clock      (clock),
        .sign       (sign_r),
        .subtract   (subtract_r),
        .A_High     (C[63:48]),
        .B_High     (Product[63:48]),
        .CARRYIN    (Lo_CARRYOUT),
        .CEB        (Hi_CEB),
        .CEC        (Hi_CEC),
        .CEP        (Hi_CEP),
        .CEOPMODE   (Hi_CEOPMODE),
        .S          (Hi_S)
    );

endmodule

