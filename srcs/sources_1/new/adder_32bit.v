`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Adder
// Sign-Magnitude Representation and Combinational Logic
//////////////////////////////////////////////////////////////////////////////////

module adder #(parameter DATA_WIDTH = 16)(
    //set result the same value as input a 
    input                                seta,
    input[DATA_WIDTH*2-1:0]              a,
    input[DATA_WIDTH*2-1:0]              b,
    output reg[DATA_WIDTH*2-1:0]        out
    );
    always @ (*) begin
       if(seta)                                             out = a;
       else if(a[DATA_WIDTH*2-1] == b[DATA_WIDTH*2-1])      out = {a[DATA_WIDTH*2-1], a[DATA_WIDTH*2-2:0] + b[DATA_WIDTH*2-2:0]};
       else if(a[DATA_WIDTH*2-2:0] < b[DATA_WIDTH*2-2:0])   out = {b[DATA_WIDTH*2-1], b[DATA_WIDTH*2-2:0] - a[DATA_WIDTH*2-2:0]};
       else                                                 out = {a[DATA_WIDTH*2-1], a[DATA_WIDTH*2-2:0] - b[DATA_WIDTH*2-2:0]};
    end
endmodule