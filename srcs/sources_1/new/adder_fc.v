`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Adder for full connected layer
// this adder use procedural logic, use registers to save the results. 
//////////////////////////////////////////////////////////////////////////////////


module adder_fc #(parameter DATA_WIDTH = 16)(
    //set result the same value as input a 
    input                                clk,
    input                                seta,
    input[DATA_WIDTH*2-1:0]              a,
    input[DATA_WIDTH*2-1:0]              b,
    output reg[DATA_WIDTH*2-1:0]        out
    );
    always @ (posedge clk) begin
       if(seta)                                             out <= a;
       else if(a[DATA_WIDTH*2-1] == b[DATA_WIDTH*2-1])      out <= {a[DATA_WIDTH*2-1], a[DATA_WIDTH*2-2:0] + b[DATA_WIDTH*2-2:0]};
       else if(a[DATA_WIDTH*2-2:0] < b[DATA_WIDTH*2-2:0])   out <= {b[DATA_WIDTH*2-1], b[DATA_WIDTH*2-2:0] - a[DATA_WIDTH*2-2:0]};
       else                                                 out <= {a[DATA_WIDTH*2-1], a[DATA_WIDTH*2-2:0] - b[DATA_WIDTH*2-2:0]};
    end
endmodule
