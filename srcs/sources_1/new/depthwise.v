`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/14 17:17:58
// Design Name: 
// Module Name: depthwise
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



module depthwise #(parameter DATA_WIDTH = 8,parameter KERNEL_SIZE = 3,parameter CHANNEL_PARALLELISM = 4,parameter PADDING = 1)(
    input clk,
    input en,
    input init_buffer,
    input input_window_done,
    input next_en,
    input point_done,
    input[7:0] input_size,
    input[7:0] output_size,
    input[7:0] channel, 
    input[3:0] layer,
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] input_feature1,//channel-wise
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] input_feature2,
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] input_feature3,
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] input_feature4, 
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE*CHANNEL_PARALLELISM-1:0] input_weight,//
    output[DATA_WIDTH*1*1*CHANNEL_PARALLELISM-1:0]output_feature,
    output reg[7:0] channel_sel=0,
    output[7:0] channel_sel_delay3,
    output reg depth_doing=0,
    output reg first_cycle=0,
    output channel_done,    
    output depth33_done,
    output layer_done,
    output done
    );
     wire com_done[3:0];
    always@(posedge clk)begin
        if(channel<4)begin
            if(en)begin
                first_cycle<=1;
            end
            if(first_cycle)
                first_cycle<=0;
        end
        else begin
            if(channel_sel==24)begin
                first_cycle<=1;
            end
            if(first_cycle)
                first_cycle<=0;
        end
    end
   //calculate one cycle later than channel sel
    reg[7:0] dep_sel=0;
    always@(posedge clk)begin
        dep_sel<=channel_sel_delay3;
    end
    //3+32+32
    (*ram_style = "block"*)reg[DATA_WIDTH*2-1:0] bias[66:0];
    initial begin
       $readmemb("D:/weights/depth_bias.txt",bias);
    end
    
    reg[7:0] h=0,w=0;
    always@(posedge clk)begin
        if(depth33_done)begin
            if(w<input_size)begin
                if(w==input_size-1)begin
                    if(h<input_size)begin
                        if(h==input_size-1)begin
                            h<=0;
                        end
                        else h<=h+1;
                    end
                    w<=0;
                end
                else w<=w+1;
            end
        end
    end
    //whole feature depthwise done
    assign done = h==input_size-1&&w==input_size-1&&depth33_done;
    //one layer depthwise done
    assign layer_done = w==input_size-1&&first_cycle;
    
    //是否已经开始计算
    reg started = 0;
    
    //depth doing, for writing enable signal at intermediate buffer
    always@(posedge clk)begin
        if(started) depth_doing<=1;
        else depth_doing <= 0;
    end
    
    always@(posedge clk)begin
        if(en&&!init_buffer) started <= 1;
        else if(depth33_done) started<=0;
    end   
    
    //calculate channel select
    always@(posedge clk)begin
           if(en)begin
                channel_sel<=0;
            end
            else if(channel<=4)channel_sel<=0;
            else if(depth33_done) channel_sel<=0;
            else if((started&&channel_sel<channel-4))
                channel_sel <= channel_sel + 4;
           else if(channel_done&&com_done[0])begin
               channel_sel <= 0;
           end
    end
        //读出1，2，3，4  3*3 data
//    wire[DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] input1,input2,input3,input4;
//    assign input1 = input_feature1[0*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
//    assign input2 = input_feature2[1*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
//    assign input3 = input_feature3[2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
//    assign input4 = input_feature4[3*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    
        //读出1，2，3，4  3*3 weight
    wire[DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] weight1,weight2,weight3,weight4;
    assign weight1 = input_weight[0*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    assign weight2 = input_weight[1*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    assign weight3 = input_weight[2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    assign weight4 = input_weight[3*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    wire[DATA_WIDTH*2-1:0] result[3:0];
    
        wire[7:0] channel_sel_delay3_copy[3:0];
    assign channel_sel_delay3 = channel_sel_delay3_copy[0];
    //4个 compute engine 并行工作,计算四个channel
    compute_engine #(DATA_WIDTH)com1(clk,en,channel_done,started,channel_sel,input_feature1,weight1,result[0],channel_sel_delay3_copy[0],com_done[0]);
    compute_engine  #(DATA_WIDTH)com2(clk,en,channel_done,started,channel_sel,input_feature2,weight2,result[1],channel_sel_delay3_copy[1],com_done[1]);
    compute_engine  #(DATA_WIDTH)com3(clk,en,channel_done,started,channel_sel,input_feature3,weight3,result[2],channel_sel_delay3_copy[2],com_done[2]);
    compute_engine #(DATA_WIDTH) com4(clk,en,channel_done,started,channel_sel,input_feature4,weight4,result[3],channel_sel_delay3_copy[3],com_done[3]);
    
    //cal channel done
    assign channel_done = started&&(channel_sel>=channel-4||channel<=4);
    
    assign depth33_done = channel_done&&com_done[0];
   
    //add bias
    wire[DATA_WIDTH*2-1:0] result_bias[3:0];
    wire[7:0] base_addr;
    assign base_addr = layer<4?0:(layer<8?3:35);
        
    (* use_dsp = "no" *)assign result_bias[0] = result[0]+bias[base_addr+dep_sel];
   (* use_dsp = "no" *) assign result_bias[1] = result[1]+bias[base_addr+dep_sel+1];
   (* use_dsp = "no" *) assign result_bias[2] = result[2]+bias[base_addr+dep_sel+2];
   (* use_dsp = "no" *) assign result_bias[3] = channel<4?0:result[3]+bias[base_addr+dep_sel+3];
    
    //quantization
    wire[DATA_WIDTH*2-1:0] result_quan[3:0];
    wire[7:0] shift_num;
    assign shift_num = layer<4?7:(layer<8?7:8);
    
    assign result_quan[0] = {result_bias[0]>>>shift_num};
    assign result_quan[1] = {result_bias[1]>>>shift_num};
    assign result_quan[2] = {result_bias[2]>>>shift_num};
    assign result_quan[3] = {result_bias[3]>>>shift_num};
    
    //output
    assign output_feature[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[0][DATA_WIDTH*2-1],result_quan[0][DATA_WIDTH-2:0]};
    assign output_feature[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[1][DATA_WIDTH*2-1],result_quan[1][DATA_WIDTH-2:0]};
    assign output_feature[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[2][DATA_WIDTH*2-1],result_quan[2][DATA_WIDTH-2:0]};
    assign output_feature[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[3][DATA_WIDTH*2-1],result_quan[3][DATA_WIDTH-2:0]};
    

endmodule
