`timescale 1ns / 1ps
/*
 * File         : PriorityEncoder_16x4.v
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
 *   A 16-to-4 priority encoder with highest-bit priority.
 */
module PriorityEncoder_16x4(Encoder_In, Address_Out, Match);
    input  [15:0] Encoder_In;
    output [3:0]  Address_Out;
    output        Match;

    reg [3:0] Address_Out;

    always @(Encoder_In) begin
        if      (Encoder_In[15]) Address_Out <= 15;
        else if (Encoder_In[14]) Address_Out <= 14;
        else if (Encoder_In[13]) Address_Out <= 13;
        else if (Encoder_In[12]) Address_Out <= 12;
        else if (Encoder_In[11]) Address_Out <= 11;
        else if (Encoder_In[10]) Address_Out <= 10;
        else if (Encoder_In[9])  Address_Out <= 9;
        else if (Encoder_In[8])  Address_Out <= 8;
        else if (Encoder_In[7])  Address_Out <= 7;
        else if (Encoder_In[6])  Address_Out <= 6;
        else if (Encoder_In[5])  Address_Out <= 5;
        else if (Encoder_In[4])  Address_Out <= 4;
        else if (Encoder_In[3])  Address_Out <= 3;
        else if (Encoder_In[2])  Address_Out <= 2;
        else if (Encoder_In[1])  Address_Out <= 1;
        else if (Encoder_In[0])  Address_Out <= 0;
        else                     Address_Out <= {16{1'b0}}; // XXX revert to x
    end

    assign Match = (Encoder_In != {16{1'b0}});

endmodule

