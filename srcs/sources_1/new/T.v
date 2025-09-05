`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: 
// 
//////////////////////////////////////////////////////////////////////////////////


module T(
    input               clk,
    output[3:0]         led
    );
    //clock
    wire                clk_33;
    clk_wiz_0 clk_wiz_0(
        .reset(1'b0),
        .clk_in1(clk),
        .clk_out1(clk_33),
        .locked()
    );
    wire[9:0]           TOP_out;
    TOP TOP(
    .clk(clk_33),
    .out(TOP_out)
    );
    // use leds to show 4 signs of the 10 TOP results. 
    //we don't implement classification method
    assign led[0]=TOP_out[1];
    assign led[1]=TOP_out[2];
    assign led[2]=TOP_out[3];
    assign led[3]=TOP_out[0];
endmodule
