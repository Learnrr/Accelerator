`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description:  max pooling engine
// combinational logic
//////////////////////////////////////////////////////////////////////////////////


module max_pool #(parameter DATA_WIDTH = 16)(
    input[DATA_WIDTH-1:0]                 a,
    input[DATA_WIDTH-1:0]                 b,
    output reg[DATA_WIDTH-1:0]            out
    );
    //select max one from 2 inputs    
    always@(*)begin       
        if(a[DATA_WIDTH-1]==b[DATA_WIDTH-1]&&a[DATA_WIDTH-1]==1)      out = {a[DATA_WIDTH-2:0]<b[DATA_WIDTH-2:0]?a:b};
        else if(a[DATA_WIDTH-1]==b[DATA_WIDTH-1]&&a[DATA_WIDTH-1]==0) out = {a[DATA_WIDTH-2:0]>b[DATA_WIDTH-2:0]?a:b};
        else if(a[DATA_WIDTH-1]>b[DATA_WIDTH-1])                      out = b;
        else                                                          out = a;
    end
   
endmodule
