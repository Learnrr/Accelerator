`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/14 17:19:22
// Design Name: 
// Module Name: multiply_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//0_00000_000000000000

module multiply_unit_fc #(parameter DATA_WIDTH=8) (
    input[DATA_WIDTH-1:0] a,
    input[DATA_WIDTH-1:0] b,
   output [DATA_WIDTH*2-1:0] result
    );

    assign result = a*b;

endmodule