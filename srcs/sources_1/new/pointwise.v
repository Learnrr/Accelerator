`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/25 15:02:01
// Design Name: 
// Module Name: pointwise
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


module pointwise #(parameter DATA_WIDTH = 8)(
    input clk,
    input en,
    input input_window_done,
    input[7:0] output_size,
    input[7:0] input_channel,
    input[7:0] output_channel, 
    input[3:0] layer,
    input[DATA_WIDTH*1*1*8-1:0] input_feature,
    input[DATA_WIDTH*8*8-1:0] input_weight,
    output [DATA_WIDTH*1*1*8-1:0] output_feature,
    output reg[7:0] out_h,
    output reg[7:0] out_w,
    output reg[7:0] input_channel_sel,
    output reg[7:0] output_channel_sel,
    output [7:0] input_channel_sel_delay3,
    output [7:0] output_channel_sel_delay3,
    output wire point_11_channel_done,
    output wire point11_done,    
    output reg next_en = 0,
    output reg point_doing=0,
    output done_delay
    );
    wire done;  
    wire output_channel_done,input_channel_done;
    //if started
    reg started = 0;
    //point doing for write enable signal at intermediate buffer 
    always@(posedge clk)begin
        if(started)point_doing<=1;
        else point_doing<=0;
    end
   always@(posedge clk)begin
        if(layer<4&&point_11_channel_done) started<=0;
        if(layer>=4&&layer<8&&point_11_channel_done) started<=0;
        if(layer>=8&&point_11_channel_done) started<=0;

        if(en) started <= 1;
    end
        //calculate one cycle later than channel, for right address
    reg[7:0] poc_sel=0;
    always@(posedge clk)begin
        poc_sel<=output_channel_sel_delay3;
    end
    reg[7:0] pic_sel=0;
    always@(posedge clk)begin
        pic_sel<=input_channel_sel_delay3;
    end
     //pipeline: when to start next depthwise(only for point time longer than depth)
   always@(posedge clk)begin
        if(done_delay)begin
            next_en<=0;
        end
        else if(layer<4&&output_channel_sel==8'h00&&started)begin
            next_en<=1;
        end 
        else if(layer>=4&&layer<8&&output_channel_sel==8'h00&&input_channel_sel==8'h10)begin//16,24
            next_en<=1;
        end
        else if(layer>=8&&layer<12&&output_channel_sel==8'h20&&input_channel_sel==8'h10)begin//48,24
            next_en<=1;
        end
        else if(input_window_done)begin
            next_en<=0;
        end
    end

    
    (*ram_style="block"*)reg[DATA_WIDTH*2-1:0] bias[127:0];
    initial begin
        input_channel_sel = 0;
        output_channel_sel = 0;
        out_h = 0;
        out_w = 0;
        $readmemb("D:/weights/point_bias.txt",bias);
    end 
    
    //pack one-dime input to 2-dim
    wire[DATA_WIDTH-1:0] inweight[8-1:0][8-1:0];

    genvar i,j,k;
    generate
        for(i=0;i<8;i=i+1)begin
            for(j=0;j<8;j=j+1)begin
                assign inweight[7-i][7-j] = input_weight[(i*8+j)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    endgenerate
    //whole feature pointwise done
    assign done = out_h==output_size-1&&out_w==output_size-1&&input_channel_done&&output_channel_done;
    
    //output address
    always@(posedge clk)begin
        if(done_delay)begin
            out_h<=0;
            out_w<=0;
        end
        else if(point11_done)begin
             if(out_w<output_size)begin
                
                if(out_w == output_size-1)begin
                    if(out_h<output_size)begin
                        if(out_h == output_size-1)begin
                            out_h <= 0;
                        end
                        else out_h <= out_h+1;
                    end
                    else out_h <= 0;
                    out_w<=0;
                end
                else out_w <= out_w + 1;
                
             end
             else out_w<=0;
        end
        else begin
            out_h<=out_h;
            out_w<=out_w;
        end
    end
     reg[7:0] outh_delay=0,outw_delay=0;
    reg[7:0] outh_delay2=0,outw_delay2=0;
    reg[7:0] outh_delay3=0,outw_delay3=0;
    always@(posedge clk)begin
        outh_delay<=out_h;outw_delay<=out_w;
        outh_delay2<=outh_delay;outw_delay2<=outw_delay;
        outh_delay3<=outh_delay2;outw_delay3<=outw_delay2;
    end
    assign done_delay = outw_delay3==output_size-1&&outh_delay3==output_size-1&&point11_done;
    //order for compute
    wire[DATA_WIDTH*8-1:0] weight_block_line[8-1:0];
    generate 
        for(i=0;i<8;i=i+1)begin
            for(j=0;j<8;j=j+1)begin
                assign weight_block_line[i][j*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] = inweight[i][j];
            end
        end
    endgenerate
    
     //input channel done
     assign input_channel_done = started&&(input_channel<=8||input_channel_sel>=input_channel-8);
    //output channel done
     assign output_channel_done = started&&(output_channel<=8||output_channel_sel>=output_channel-8);
     
     assign point_11_channel_done = input_channel_done&&output_channel_done;

        assign point11_done = (layer<4&&output_channel_sel_delay3==8'h18)
     ||(layer<8&&layer>=4&&output_channel_sel_delay3==8'h18&&input_channel_sel_delay3==8'h18)
     ||(layer>=8&&output_channel_sel_delay3==8'h38&&input_channel_sel_delay3==8'h18);
     
     //cal inchannel sel
      always@(posedge clk)begin
            if(en)begin
                input_channel_sel<=0;
            end
           // else if(wait_clk>1) channel_sel<=0;
            else if(input_channel_done) input_channel_sel<=0;
            else if(started&&input_channel_sel<input_channel-8)
                input_channel_sel <= input_channel_sel + 8;

    end
    //cal outchannel sel
    always@(posedge clk)begin
        if(en) output_channel_sel<=0;
       // else if(point11_done) output_channel_sel<=0;
       else if(done_delay) output_channel_sel<=0;
        else if(output_channel_done&&input_channel_done)begin
            output_channel_sel<=0;
        end
        else if(input_channel_done&&started&&output_channel_sel<output_channel-8) output_channel_sel<=output_channel_sel+8;
       
        else if(input_channel_done)output_channel_sel<=0;
      //  else output_channel_sel <= output_channel_sel;
    end
    
    //8*8 compute
    wire[DATA_WIDTH*2-1:0] result[7:0];
    wire[7:0] output_channel_sel_delay3_copy[7:0],input_channel_sel_delay3_copy[7:0];
    assign output_channel_sel_delay3 = output_channel_sel_delay3_copy[0];
    assign input_channel_sel_delay3 = input_channel_sel_delay3_copy[0];
    generate
        for(i=0;i<8;i=i+1)begin
            compute_engine_p com(clk,
            input_channel_done,
            output_channel_done,
            input_channel_sel,
            output_channel_sel,
            input_feature,
            weight_block_line[i],
            result[i],
            input_channel_sel_delay3_copy[i],
            output_channel_sel_delay3_copy[i]);
        end
    endgenerate
    


    //add bias
    wire[DATA_WIDTH*2-1:0] result_bias[7:0];
    wire[7:0] base_addr;
    assign base_addr = layer<4?0:(layer<8?32:64);    
//one outputchannel add bias once
    assign result_bias[0] = pic_sel>0?result[0]:result[0]+bias[base_addr+poc_sel+0];
    assign result_bias[1] = pic_sel>0?result[1]:result[1]+bias[base_addr+poc_sel+1];
    assign result_bias[2] = pic_sel>0?result[2]:result[2]+bias[base_addr+poc_sel+2];
    assign result_bias[3] = pic_sel>0?result[3]:result[3]+bias[base_addr+poc_sel+3];
    assign result_bias[4] = pic_sel>0?result[4]:result[4]+bias[base_addr+poc_sel+4];
    assign result_bias[5] = pic_sel>0?result[5]:result[5]+bias[base_addr+poc_sel+5];
    assign result_bias[6] = pic_sel>0?result[6]:result[6]+bias[base_addr+poc_sel+6];
    assign result_bias[7] = pic_sel>0?result[7]:result[7]+bias[base_addr+poc_sel+7];
    
    //quantization
    wire[DATA_WIDTH*2-1:0] result_quan[7:0];
    wire[7:0] shift_num;
    assign shift_num = layer<4?6:(layer<8?7:6);    
    assign result_quan[0] = {result_bias[0][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[1] = {result_bias[1][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[2] = {result_bias[2][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[3] = {result_bias[3][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[4] = {result_bias[4][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[5] = {result_bias[5][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[6] = {result_bias[6][DATA_WIDTH*2-1:0]>>>shift_num};
    assign result_quan[7] = {result_bias[7][DATA_WIDTH*2-1:0]>>>shift_num};
    
    //output
   assign output_feature[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[0][DATA_WIDTH*2-1],result_quan[0][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[1][DATA_WIDTH*2-1],result_quan[1][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[2][DATA_WIDTH*2-1],result_quan[2][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[3][DATA_WIDTH*2-1],result_quan[3][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[4][DATA_WIDTH*2-1],result_quan[4][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[5][DATA_WIDTH*2-1],result_quan[5][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[6][DATA_WIDTH*2-1],result_quan[6][DATA_WIDTH-2:0]};
   assign output_feature[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[7][DATA_WIDTH*2-1],result_quan[7][DATA_WIDTH-2:0]};
    
endmodule
