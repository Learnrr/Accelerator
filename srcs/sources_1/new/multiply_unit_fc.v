`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: multiply unit
// Combinational Logic
//used for fc layers. fc layers needs more improvement
//////////////////////////////////////////////////////////////////////////////////

module multiply_unit_fc #(parameter DATA_WIDTH = 16)(
    input[DATA_WIDTH-1:0]               a,
    input[DATA_WIDTH-1:0]               b,
    output[DATA_WIDTH*2-1:0]            result
    );
    wire[DATA_WIDTH*2-2:0]              c;
    assign c = a[DATA_WIDTH-2:0]*b[DATA_WIDTH-2:0];
    assign result = (a[DATA_WIDTH-2:0]=='b0||b[DATA_WIDTH-2:0]=='b0)? 'b0:{a[DATA_WIDTH-1]^b[DATA_WIDTH-1],c};
     
endmodule
