`timescale 1ns / 1ps
/*
 * File         : RAM_TDP_UI.v
 * Project      : XUM MIPS32
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   6-Nov-2014   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A dual-ported write-first memory of configurable width and
 *   depth, made to be inferred as a Xilinx Block RAM (BRAM).
 *
 *   TDP-> True dual-port (two read and two write ports)
 *   UI->  User-initialized data
 *
 *   Read data is available at the next clock edge.
 *   Reset will zero the outputs on the next clock edge.
 */
module RAM_TDP_UI(clk, rst, addra, wea, dina, douta, addrb, web, dinb, doutb);
    parameter  DATA_WIDTH = 128;
    parameter  ADDR_WIDTH = 12;
    parameter  INIT_FILE  = "data.hex";
    localparam RAM_DEPTH  = 1 << ADDR_WIDTH;
    input  clk;
    input  rst;
    input  [(ADDR_WIDTH-1):0] addra;
    input  wea;
    input  [(DATA_WIDTH-1):0] dina;
    output [(DATA_WIDTH-1):0] douta;
    input  [(ADDR_WIDTH-1):0] addrb;
    input  web;
    input  [(DATA_WIDTH-1):0] dinb;
    output [(DATA_WIDTH-1):0] doutb;

    reg [(DATA_WIDTH-1):0] douta;
    reg [(DATA_WIDTH-1):0] doutb;

    // Hint for {AUTO, BLOCK, DISTRIBUTED}
    (* RAM_STYLE="BLOCK" *)
    reg [(DATA_WIDTH-1):0] ram [0:(RAM_DEPTH-1)];

    initial begin
        $readmemh(INIT_FILE, ram, 0, (RAM_DEPTH-1));
    end

    always @(posedge clk) begin
        douta <= ram[addra];
        if (wea) begin
            ram[addra] <= dina;
            douta <= dina;
        end
        if (rst) begin
            douta <= {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        doutb <= ram[addrb];
        if (web) begin
            ram[addrb] <= dinb;
            doutb <= dinb;
        end
        if (rst) begin
            doutb <= {DATA_WIDTH{1'b0}};
        end
    end

endmodule

