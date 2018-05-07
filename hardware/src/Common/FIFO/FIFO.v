`timescale 1ns / 1ps
/*
 * File         : FIFO.v
 * Project      : University of Utah, XUM Project MIPS32 core
 * Creator(s)   : Grant Ayers (ayers@cs.utah.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   4-Apr-2010   GEA       Initial design.
 *
 * Standards/Formatting:
 *   Verilog 2001, 4 soft tab, wide column.
 *
 * Description:
 *   A synchronous FIFO of variable data width and depth. 'enQ' is ignored when
 *   the FIFO is full and 'deQ' is ignored when the FIFO is empty. If 'enQ' and
 *   'deQ' are asserted simultaneously, the FIFO is unchanged and the output data
 *   is the same as the input data.
 *
 *   This FIFO is "First word fall-through" meaning data can be read without
 *   asserting 'deQ' by merely supplying an address. However, when 'deQ' is
 *   asserted, the data is "removed" from the FIFO and one location is freed.
 *   'enQ' and 'deQ' should not be asserted simultaneously.
 *
 * Variation:
 *   - None. This is the basic FIFO module.
 */
module FIFO(clock, reset, enQ, deQ, data_in, data_out, empty, full);
   parameter DATA_WIDTH = 8;
   parameter ADDR_WIDTH = 8;
   parameter RAM_DEPTH = 1 << ADDR_WIDTH;
   input clock;
   input reset;
   input enQ;
   input deQ;
   input [(DATA_WIDTH-1):0] data_in;
   output [(DATA_WIDTH-1):0] data_out;
   output empty;
   output full;

   reg [(ADDR_WIDTH-1):0] enQ_ptr, deQ_ptr;     // Addresses for reading from and writing to internal memory
   reg [(ADDR_WIDTH):0] count;                  // How many elements are in the FIFO (0->256)
   assign empty = (count == {ADDR_WIDTH+1{1'b0}});
   assign full = (count == (1 << ADDR_WIDTH));

   wire [(DATA_WIDTH-1):0] w_data_out;
   assign data_out = w_data_out;

   wire w_enQ = enQ;
   wire w_deQ = deQ;

   always @(posedge clock) begin
      if (reset) begin
         enQ_ptr <= {ADDR_WIDTH{1'b0}};
         deQ_ptr <= {ADDR_WIDTH{1'b0}};
         count <= {ADDR_WIDTH+1{1'b0}};
      end
      else begin
         enQ_ptr <= (w_enQ) ? enQ_ptr + 1'b1 : enQ_ptr;
         deQ_ptr <= (w_deQ) ? deQ_ptr + 1'b1 : deQ_ptr;
         count <= (w_enQ ~^ w_deQ) ? count : ((w_enQ) ? count + 1'b1 : count - 1'b1);
      end
   end

   SRAM #(
      .DATA_WIDTH (DATA_WIDTH),
      .ADDR_WIDTH (ADDR_WIDTH),
      .RAM_DEPTH  (RAM_DEPTH))
      RAM(
      .clock   (clock),
      .wEn     (w_enQ),
      .rAddr   (deQ_ptr),
      .wAddr   (enQ_ptr),
      .dIn     (data_in),
      .dOut    (w_data_out)
   );

endmodule

