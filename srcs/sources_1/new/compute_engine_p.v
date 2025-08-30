`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/14 17:18:35
// Design Name: 
// Module Name: compute_engine_p
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



module compute_engine_p #(parameter DATA_WIDTH=8)(
    input clk,
    input input_channel_done,
    input output_channel_done,
    input[7:0] input_channel_sel,
    input[7:0] output_channel_sel,
   input[DATA_WIDTH*8-1:0] data,
    input[DATA_WIDTH*8-1:0] weight,
    output[DATA_WIDTH*2-1:0] result,
    output reg[7:0] input_channel_sel_delay3=0,
    output reg[7:0] output_channel_sel_delay3=0
    );
  
    reg[7:0] input_channel_sel_delay1=0;
    reg[7:0] output_channel_sel_delay1=0;
    
    reg signed[DATA_WIDTH-1:0] temp_data0;
    reg signed[DATA_WIDTH-1:0] temp_data1; 
    reg signed[DATA_WIDTH-1:0] temp_data2;
    reg signed[DATA_WIDTH-1:0] temp_data3;
    reg signed[DATA_WIDTH-1:0] temp_data4;
    reg signed[DATA_WIDTH-1:0] temp_data5;
    reg signed[DATA_WIDTH-1:0] temp_data6;
    reg signed[DATA_WIDTH-1:0] temp_data7;
                 
    reg signed[DATA_WIDTH-1:0] temp_weight0;
    reg signed[DATA_WIDTH-1:0] temp_weight1;
    reg signed[DATA_WIDTH-1:0] temp_weight2;
    reg signed[DATA_WIDTH-1:0] temp_weight3;
    reg signed[DATA_WIDTH-1:0] temp_weight4;
    reg signed[DATA_WIDTH-1:0] temp_weight5;
    reg signed[DATA_WIDTH-1:0] temp_weight6;
    reg signed[DATA_WIDTH-1:0] temp_weight7;
 
   
   wire signed[DATA_WIDTH*2-1:0] intermediate_result0;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result1;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result2;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result3;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result4;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result5;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result6;
    wire signed[DATA_WIDTH*2-1:0] intermediate_result7; 
     //一维数组展开为二维数组
     always@(posedge clk)begin
      temp_data0 <= data[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data1 <= data[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data2 <= data[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data3 <= data[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data4 <= data[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data5 <= data[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data6 <= data[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_data7 <= data[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH];
     
      temp_weight0 <=  weight[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight1 <=  weight[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight2 <=  weight[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight3 <=  weight[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight4 <=  weight[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight5 <=  weight[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight6 <=  weight[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH];
      temp_weight7 <=  weight[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH];
      
      input_channel_sel_delay1<=input_channel_sel;
      output_channel_sel_delay1<=output_channel_sel;
   end
     multiply_unit #(DATA_WIDTH)mul0(.clk(clk),.a(temp_data0),.b(temp_weight0),.result(intermediate_result0));
     multiply_unit #(DATA_WIDTH)mul1(.clk(clk),.a(temp_data1),.b(temp_weight1),.result(intermediate_result1));
     multiply_unit #(DATA_WIDTH)mul2(.clk(clk),.a(temp_data2),.b(temp_weight2),.result(intermediate_result2));
     multiply_unit #(DATA_WIDTH)mul3(.clk(clk),.a(temp_data3),.b(temp_weight3),.result(intermediate_result3));
     multiply_unit #(DATA_WIDTH)mul4(.clk(clk),.a(temp_data4),.b(temp_weight4),.result(intermediate_result4));
     multiply_unit #(DATA_WIDTH)mul5(.clk(clk),.a(temp_data5),.b(temp_weight5),.result(intermediate_result5));
     multiply_unit #(DATA_WIDTH)mul6(.clk(clk),.a(temp_data6),.b(temp_weight6),.result(intermediate_result6));
     multiply_unit #(DATA_WIDTH)mul7(.clk(clk),.a(temp_data7),.b(temp_weight7),.result(intermediate_result7));
     
     reg[7:0] input_channel_sel_delay2=0;
    reg[7:0] output_channel_sel_delay2=0;    
    always@(posedge clk)begin
        input_channel_sel_delay2<=input_channel_sel_delay1;
        output_channel_sel_delay2<=output_channel_sel_delay1;
    end
    
    //结果相加
(*use_dsp="no"*) wire signed [DATA_WIDTH*2-1:0] sum_01 = intermediate_result0 + intermediate_result1;
(*use_dsp="no"*)wire signed [DATA_WIDTH*2-1:0] sum_23 = intermediate_result2 + intermediate_result3;
(*use_dsp="no"*)wire signed [DATA_WIDTH*2-1:0] sum_45 = intermediate_result4 + intermediate_result5;
(*use_dsp="no"*)wire signed [DATA_WIDTH*2-1:0] sum_67 = intermediate_result6 + intermediate_result7;

//(*use_dsp="no"*)wire signed [DATA_WIDTH*2-1:0] sum_0123 = sum_01 + sum_23;
//(*use_dsp="no"*)wire signed [DATA_WIDTH*2-1:0] sum_4567 = sum_45 + sum_67;
    reg[31:0] sum_0123_delay,sum_4567_delay;
    always@(posedge clk)begin
         sum_0123_delay<=sum_01 + sum_23;
         sum_4567_delay<=sum_45 + sum_67;
         input_channel_sel_delay3<=input_channel_sel_delay2;
         output_channel_sel_delay3<=output_channel_sel_delay2;
    end
assign result =sum_0123_delay+sum_4567_delay;

endmodule
