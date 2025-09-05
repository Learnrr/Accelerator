`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/14 17:50:09
// Design Name: 
// Module Name: compute_engine
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


//3*3 compute engine
module compute_engine #(parameter DATA_WIDTH=8)(
    input clk,
    input en,
    input channel_done,
    input started,
    input[7:0] channel_sel,
    input[DATA_WIDTH*9-1:0] data,
    input[DATA_WIDTH*9-1:0] weight,
    output signed[DATA_WIDTH*2-1:0] result,
    output reg[7:0] channel_sel_delay3=0,
    output done
    );
      reg[1:0] clk_count=0;
    
    always@(posedge clk)begin
        if(en)begin clk_count<=0;end
        else if(done) clk_count<=0;
        else if(started&&channel_done)clk_count<=clk_count==3?0:clk_count+1;  
           
    end
    assign done = clk_count==3;
     reg signed[DATA_WIDTH-1:0] temp_data0;
    reg signed[DATA_WIDTH-1:0] temp_data1; 
    reg signed[DATA_WIDTH-1:0] temp_data2;
    reg signed[DATA_WIDTH-1:0] temp_data3;
    reg signed[DATA_WIDTH-1:0] temp_data4;
    reg signed[DATA_WIDTH-1:0] temp_data5;
    reg signed[DATA_WIDTH-1:0] temp_data6;
    reg signed[DATA_WIDTH-1:0] temp_data7;
    reg signed[DATA_WIDTH-1:0] temp_data8;
                 
    reg signed[DATA_WIDTH-1:0] temp_weight0;
    reg signed[DATA_WIDTH-1:0] temp_weight1;
    reg signed[DATA_WIDTH-1:0] temp_weight2;
    reg signed[DATA_WIDTH-1:0] temp_weight3;
    reg signed[DATA_WIDTH-1:0] temp_weight4;
    reg signed[DATA_WIDTH-1:0] temp_weight5;
    reg signed[DATA_WIDTH-1:0] temp_weight6;
    reg signed[DATA_WIDTH-1:0] temp_weight7;
    reg signed[DATA_WIDTH-1:0] temp_weight8;
    
    reg[7:0] channel_sel_delay=0;
 
    wire signed[DATA_WIDTH*2-1:0] intermediate_result0;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result1;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result2;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result3;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result4;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result5;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result6;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result7;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result8; 
    
    always@(posedge clk)begin
      temp_data0 <= data[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data1 <= data[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data2 <= data[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data3 <= data[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data4 <= data[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data5 <= data[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data6 <= data[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data7 <= data[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data8 <= data[DATA_WIDTH*8+DATA_WIDTH-1 -: DATA_WIDTH];
     
      temp_weight0 <=  weight[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight1 <=  weight[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight2 <=  weight[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight3 <=  weight[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight4 <=  weight[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight5 <=  weight[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight6 <=  weight[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight7 <=  weight[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight8 <=  weight[DATA_WIDTH*8+DATA_WIDTH-1 -: DATA_WIDTH];
      
      channel_sel_delay<=channel_sel;
   end

    multiply_unit #(DATA_WIDTH)mul0(.clk(clk),.a(temp_data0),.b(temp_weight0),.result(intermediate_result0));
     multiply_unit #(DATA_WIDTH)mul1(.clk(clk),.a(temp_data1),.b(temp_weight1),.result(intermediate_result1));
     multiply_unit #(DATA_WIDTH)mul2(.clk(clk),.a(temp_data2),.b(temp_weight2),.result(intermediate_result2));
     multiply_unit #(DATA_WIDTH)mul3(.clk(clk),.a(temp_data3),.b(temp_weight3),.result(intermediate_result3));
     multiply_unit #(DATA_WIDTH)mul4(.clk(clk),.a(temp_data4),.b(temp_weight4),.result(intermediate_result4));
     multiply_unit #(DATA_WIDTH)mul5(.clk(clk),.a(temp_data5),.b(temp_weight5),.result(intermediate_result5));
     multiply_unit #(DATA_WIDTH)mul6(.clk(clk),.a(temp_data6),.b(temp_weight6),.result(intermediate_result6));
     multiply_unit #(DATA_WIDTH)mul7(.clk(clk),.a(temp_data7),.b(temp_weight7),.result(intermediate_result7));
     multiply_unit #(DATA_WIDTH)mul8(.clk(clk),.a(temp_data8),.b(temp_weight8),.result(intermediate_result8));

 reg[7:0] channel_sel_delay2=0;
    always@(posedge clk)begin
        channel_sel_delay2<=channel_sel_delay;
    end
    //结果相加
wire signed [DATA_WIDTH*2-1:0] sum_01 = intermediate_result0 + intermediate_result1;
wire signed [DATA_WIDTH*2-1:0] sum_23 = intermediate_result2 + intermediate_result3;
wire signed [DATA_WIDTH*2-1:0] sum_45 = intermediate_result4+ intermediate_result5;
wire signed [DATA_WIDTH*2-1:0] sum_67 = intermediate_result6 + intermediate_result7;

//wire signed [DATA_WIDTH*2-1:0] sum_0123 = sum_01 + sum_23;
//wire signed [DATA_WIDTH*2-1:0] sum_4567 = sum_45 + sum_67;
   reg[31:0] sum_0123_delay,sum_4567_delay;
   reg[31:0] inter8_delay;
   always@(posedge clk)begin
        sum_0123_delay<=sum_01 + sum_23;
        inter8_delay<=intermediate_result8;
        sum_4567_delay<=sum_45 + sum_67;
        channel_sel_delay3<=channel_sel_delay2;
   end
   
wire signed [DATA_WIDTH*2-1:0] sum_014567 = sum_0123_delay+sum_4567_delay;
assign result = sum_014567+inter8_delay;
endmodule

