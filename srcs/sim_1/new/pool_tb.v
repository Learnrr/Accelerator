`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/03 10:07:11
// Design Name: 
// Module Name: pool_tb
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


module pool_tb();
reg clk;
wire[15:0] input_feature[7:0][15:0][15:0];
wire[7:0] inh,inw,channel_sel;
wire channel_done,done;
wire[16*4-1:0] outfeature;
wire en;
wire[16*4*4-1:0] infeature_block;

genvar i,j,k;
generate 
    for(i=0;i<8;i=i+1)begin
        for(j=0;j<16;j=j+1)begin
            for(k=0;k<16;k=k+1)begin
                assign input_feature[i][j][k] = j%3+1;
            end
        end
    end
endgenerate
generate 
    for(i=0;i<4;i=i+1)begin
        for(j=0;j<2;j=j+1)begin
            for(k=0;k<2;k=k+1)begin
                 assign infeature_block[16*(i*4+j*2+k)+15 -: 16] = input_feature[channel_sel+i][inh+j][inw+k];     
            end
        end
    end
endgenerate
initial begin
    clk = 0;
end
always#10 clk <= ~clk;
pool pool(
    clk,
    en,
    16,
    8,
    infeature_block,
    outfeature,
    inh,
    inw,
    channel_sel,
    channel_done,
    done
);
endmodule
