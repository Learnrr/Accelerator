`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/03 09:28:28
// Design Name: 
// Module Name: max_pool
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


module max_pool #(parameter DATA_WIDTH=16)(
    input[DATA_WIDTH-1:0] a,
    input[DATA_WIDTH-1:0] b,
  (*max_fanout=5*)  output reg[DATA_WIDTH-1:0] out
    );
//    assign out = $signed(a)>$signed(b)?a:b;
    
    always@(*)begin
        
        if(a[DATA_WIDTH-1]==b[DATA_WIDTH-1]&&a[DATA_WIDTH-1]==1)begin
            out = {a[DATA_WIDTH-2:0]<b[DATA_WIDTH-2:0]?a:b};
        end
        else if(a[DATA_WIDTH-1]==b[DATA_WIDTH-1]&&a[DATA_WIDTH-1]==0)begin
            out = {a[DATA_WIDTH-2:0]>b[DATA_WIDTH-2:0]?a:b};
        end
        else if(a[DATA_WIDTH-1]>b[DATA_WIDTH-1])begin
            out = b;
        end
        else out = a;
    end
   
endmodule
