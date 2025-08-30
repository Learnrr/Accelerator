`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: multiply_unit
// to do multiplies. Sign-Magnitude Representation and Sequential Logic
//////////////////////////////////////////////////////////////////////////////////

module multiply_unit#(parameter DATA_WIDTH = 16)(
    input                                     clk,
    input[DATA_WIDTH-1:0]                     a,
    input[DATA_WIDTH-1:0]                     b,
    output reg[DATA_WIDTH*2-1:0]             result
    );
    wire[DATA_WIDTH*2-2:0]                   c;
    assign c = a[DATA_WIDTH-2:0] * b[DATA_WIDTH-2:0];
    always@(posedge clk)begin
        result <= (a[DATA_WIDTH-2:0]=='b0||b[DATA_WIDTH-2:0]=='b0)? 'b0:{a[DATA_WIDTH-1]^b[DATA_WIDTH-1],c};
    end
     
endmodule