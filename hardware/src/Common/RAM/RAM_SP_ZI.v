`timescale 1ns / 1ps
/*
 * File         : RAM_SP_ZI.v
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
 *   A simple write-first memory of configurable width and
 *   depth, made to be inferred as a Xilinx Block RAM (BRAM).
 *
 *   SP-> Single-port.
 *   ZI-> Zeroed initial data.
 *
 *   Read data is available at the next clock edge.
 *   Reset will zero the outputs on the next clock edge.
 */

module RAM_SP_ZI(clk, rst, addr, we, din, dout);
    parameter  DATA_WIDTH = 128;
    parameter  ADDR_WIDTH = 12;
    localparam RAM_DEPTH  = 1 << ADDR_WIDTH;
    input  clk;
    input  rst;
    input  [(ADDR_WIDTH-1):0] addr;
    input  we;
    input  [(DATA_WIDTH-1):0] din;
    output [(DATA_WIDTH-1):0] dout;

    reg [(DATA_WIDTH-1):0] dout;

    // Hint for {AUTO, BLOCK, DISTRIBUTED}
    (* RAM_STYLE="AUTO" *)
    reg [(DATA_WIDTH-1):0] ram [0:(RAM_DEPTH-1)];

    integer i;
    initial begin
        for (i = 0; i < RAM_DEPTH; i = i + 1) begin
            ram[i] <= {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        dout <= ram[addr];
        if (we) begin
            ram[addr] <= din;
            dout <= din;
        end
        if (rst) begin
            dout <= {DATA_WIDTH{1'b0}};
        end
    end

endmodule

