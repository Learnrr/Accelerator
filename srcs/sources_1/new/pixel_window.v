`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 16:06:51
// Design Name: 
// Module Name: input_window
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


module pixel_window #(parameter PADDING = 1,parameter DATA_WIDTH=8)(
    input clk,
    input init_buffer,
    input init_buffer_done,
    input[7:0] input_size,
    input[7:0] channel, 
    input[7:0] depth_channel_sel,
    input depth_channel_done,
    input next_en,
    input depthwise_en,    
    input[DATA_WIDTH*4-1:0] data0,
    input[DATA_WIDTH*4-1:0] data1,
    input[DATA_WIDTH*4-1:0] data2,
    output reg[7:0] input_w=0, 
    output reg[7:0] input_channel=0, //in window channel
    (* keep = "true" *)output reg[DATA_WIDTH*3*3-1:0] output_feature1,
    (* keep = "true" *)output reg[DATA_WIDTH*3*3-1:0] output_feature2,
   (* keep = "true" *) output reg[DATA_WIDTH*3*3-1:0] output_feature3,
   (* keep = "true" *) output reg[DATA_WIDTH*3*3-1:0] output_feature4,
    output reg first=0,//feature first after init buffer
    output reg done=0
    );
        reg en_count=0;
    always@(posedge clk)begin
        if(depthwise_en)begin
            en_count<=en_count+1;
        end
    end    
   reg[7:0] inh=0;
   reg input_window_done=0;
   always@(posedge clk)begin
        if(init_buffer)begin
            inh<=0;
        end
        else if(input_window_done)begin
            inh<=inh;
        end
        else if(input_w==input_size-1+2*PADDING&&depth_channel_done)begin
           if(inh<input_size)begin
                  if(inh==input_size-1)begin
                        inh<=0;
                  end
                  else inh<=inh+1;
           end
        end
   end
    wire inputchannel_done;  
   assign inputchannel_done = ((input_channel==channel-4) || (channel<=4));
    always@(posedge clk)begin
        if(input_w == input_size-1+2*PADDING &&inh==input_size-1&&depth_channel_done)
            input_window_done <= 1;
        if(init_buffer)begin
            input_window_done <= 0;
        end
    end 
   reg rem=0; 
  
   reg input_doing=0;
   reg init_window=0;
   reg[7:0] inputw_delay=0;
   always@(posedge clk)begin
        inputw_delay<=input_w;
   end
   wire init_window_done;
   assign init_window_done=(input_w==2&&inputchannel_done);
   
   reg col_done = 0;
   always@(posedge clk)begin
    if(input_w==input_size-1+2*PADDING&&depth_channel_done)begin
        col_done<=1;
    end
    if(col_done&&depth_channel_done)begin
        col_done<=0;
    end
   end

   always@(posedge clk)begin
        if(init_buffer_done)begin
            init_window<=1;
        end
        else if(input_window_done)begin
            init_window<=0;
        end
        else if(init_buffer)begin
            init_window<=0;
        end    
        else if(inputw_delay==0&&depth_channel_done)begin
            init_window<=1;
        end
        if(init_window_done)begin
            init_window<=0;
        end
   end
   always@(posedge clk)begin
      if(init_buffer)begin
            done<=0;
      end
      else if(input_w==0&&col_done)begin
            done<=1;
      end
      else if(input_w<2)begin
            done<=0;
      end
      else if(init_window_done)begin
        done<=1;
      end
      else if(channel<=4&&input_w==2&&inputchannel_done)begin
            done<=0;
      end
      
      else if(input_w>=2&&inputchannel_done)begin
            done<=1;
      end
      else if(!en_count&&depth_channel_done)begin
            done<=0;
      end
   end
   always@(posedge clk)begin
        if(init_buffer)begin
            rem<=1;
            first<=0;
        end
        else if(rem&&init_window_done)begin
            first<=1;
            rem<=0;
        end
        if(first&&!init_buffer) first<=0;
   end

   
   reg[1:0] col_count=0;
   reg[2:0] col_sel[3:0];
   always@(posedge clk)begin
        if(init_buffer)begin
            col_count<=0;
        end
        else if(depthwise_en&&input_w!=3)begin
            col_count<=col_count+1;
        end
   end
   always@(*)begin
        if(col_count==0)begin
            col_sel[0] = 0;
            col_sel[1] = 1;
            col_sel[2] = 2;
            col_sel[3] = 3;
        end
        else if(col_count==1)begin
            col_sel[0] = 1;
            col_sel[1] = 2;
            col_sel[2] = 3;
            col_sel[3] = 0;
        end
        else if(col_count==2)begin
            col_sel[0] = 2;
            col_sel[1] = 3;
            col_sel[2] = 0;
            col_sel[3] = 1;
        end
        else begin
            col_sel[0] = 3;
            col_sel[1] = 0;
            col_sel[2] = 1;
            col_sel[3] = 2;
        end
   end
   
   reg input_doing_delay=0;
   always@(posedge clk)begin
        input_doing_delay<=input_doing;
   end
   always@(posedge clk)begin
        if(init_window_done)begin
            input_doing<=1;
        end
        else if(depthwise_en&&input_w!=3)begin
            input_doing<=1;
        end
        else if(inputchannel_done)begin
            input_doing<=0;
        end
   end
   always@(posedge clk)begin
        if(init_buffer)begin
            input_channel<=0;
        end
        if(input_window_done)begin
            input_channel<=0;
        end
        if(input_doing||init_window)begin
            if(channel<=4)begin
                input_channel<=0;
            end
            else if(input_channel<channel)begin
                if(input_channel==channel-4)begin
                    input_channel<=0;
                end
                else begin
                    input_channel<=input_channel+4;
                end
            end
        end
   end
   always@(posedge clk)begin
        if(init_buffer)begin
            input_w<=0;
        end
        else if(depth_channel_done&&channel<4)begin
            if(input_w==input_size+2*PADDING-1)begin
                input_w<=0;
            end
            else input_w<=input_w+1;
        end
        else if(col_done)begin
            input_w<=input_w;
        end
        else if(init_window&&inputchannel_done)begin
            input_w<=input_w+1;
        end
        else if(channel>4&&inputchannel_done)begin
            if(input_w==input_size+2*PADDING-1)begin
                input_w<=0;
            end
            else input_w<=input_w+1;
        end
   end


    reg[7:0] input_channel_delay=0;
    always@(posedge clk)begin
        input_channel_delay<=input_channel;
    end  
    
//     reg[DATA_WIDTH*4-1:0] window[2:0][3:0][7:0];
//    integer ii,jj,kk;
//    initial begin
//         for(ii=0;ii<3;ii=ii+1)begin
//            for(jj=0;jj<4;jj=jj+1)begin
//                for(kk=0;kk<8;kk=kk+1)begin
//                    window[ii][jj][kk] = 0;
//                end
//            end
//         end
//    end
//    always@(posedge clk)begin

//        if(init_window&&inputw_delay==0)begin
//            window[0][col_sel[0]][input_channel_delay/4] <= data0;
//            window[1][col_sel[0]][input_channel_delay/4] <= data1;
//            window[2][col_sel[0]][input_channel_delay/4] <= data2;
//        end
//        else if(init_window&&inputw_delay==1)begin
//            window[0][col_sel[1]][input_channel_delay/4] <= data0;
//            window[1][col_sel[1]][input_channel_delay/4] <= data1;
//            window[2][col_sel[1]][input_channel_delay/4] <= data2;
//        end
//        else if(init_window&&inputw_delay==2)begin
//            window[0][col_sel[2]][input_channel_delay/4] <= data0;
//            window[1][col_sel[2]][input_channel_delay/4] <= data1;
//            window[2][col_sel[2]][input_channel_delay/4] <= data2;
//        end        
//        else if(first)begin
//            window[0][col_sel[2]][input_channel_delay/4] <= data0;
//            window[1][col_sel[2]][input_channel_delay/4] <= data1;
//            window[2][col_sel[2]][input_channel_delay/4] <= data2;
//        end
//        else if(inputw_delay==2&&input_doing)begin
//            window[0][col_sel[2]][input_channel_delay/4] <= data0;
//            window[1][col_sel[2]][input_channel_delay/4] <= data1;
//            window[2][col_sel[2]][input_channel_delay/4] <= data2;
//        end
//        else if(input_doing_delay)begin
//            window[0][col_sel[3]][input_channel_delay/4] <= data0;
//            window[1][col_sel[3]][input_channel_delay/4] <= data1;
//            window[2][col_sel[3]][input_channel_delay/4] <= data2;
//        end
//    end
//    integer i,j,k;
//    always@(posedge clk)begin
//            for(j=0;j<3;j=j+1)begin
//                for(k=0;k<3;k=k+1)begin
//                    output_feature1[(0*3*3+j*3+k)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] <= window[j][col_sel[k]][depth_channel_sel/4][DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH];
//                    output_feature2[(0*3*3+j*3+k)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] <= window[j][col_sel[k]][depth_channel_sel/4][DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH];
//                    output_feature3[(0*3*3+j*3+k)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] <= window[j][col_sel[k]][depth_channel_sel/4][DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH];
//                    output_feature4[(0*3*3+j*3+k)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] <= window[j][col_sel[k]][depth_channel_sel/4][DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH];
//                end
//            end
//    end    
    wire w00,w01,w02,w03;
    wire w10,w11,w12,w13;
    wire w20,w21,w22,w23;
    
    wire r00,r01,r02,r03;
    wire r10,r11,r12,r13;
    wire r20,r21,r22,r23;    
    assign w00 = init_window&&inputw_delay==0;
    assign w10 = init_window&&inputw_delay==0;
    assign w20 = init_window&&inputw_delay==0;
    assign w01 = init_window&&inputw_delay==1;
    assign w11 = init_window&&inputw_delay==1;
    assign w21 = init_window&&inputw_delay==1;
    assign w02 = init_window&&inputw_delay==2||inputw_delay==2&&input_doing||first;
    assign w12 = init_window&&inputw_delay==2||inputw_delay==2&&input_doing||first;
    assign w22 = init_window&&inputw_delay==2||inputw_delay==2&&input_doing||first;   
    assign w03 = input_doing_delay;
    assign w13 = input_doing_delay;
    assign w23 = input_doing_delay;
    
    assign r00 = col_sel[0] == 0||col_sel[1]==0||col_sel[2]==0;
    assign r10 = col_sel[0] == 0||col_sel[1]==0||col_sel[2]==0;
    assign r20 = col_sel[0] == 0||col_sel[1]==0||col_sel[2]==0;
    assign r01 = col_sel[0] == 1||col_sel[1]==1||col_sel[2]==1;
    assign r11 = col_sel[0] == 1||col_sel[1]==1||col_sel[2]==1;
    assign r21 = col_sel[0] == 1||col_sel[1]==1||col_sel[2]==1;
    assign r02 = col_sel[0] == 2||col_sel[1]==2||col_sel[2]==2;
    assign r12 = col_sel[0] == 2||col_sel[1]==2||col_sel[2]==2;
    assign r22 = col_sel[0] == 2||col_sel[1]==2||col_sel[2]==2;
    assign r03 = col_sel[0] == 3||col_sel[1]==3||col_sel[2]==3;
    assign r13 = col_sel[0] == 3||col_sel[1]==3||col_sel[2]==3;
    assign r23 = col_sel[0] == 3||col_sel[1]==3||col_sel[2]==3;
    
    wire[DATA_WIDTH*4-1:0] outdata00,outdata01,outdata02,outdata03;
    wire[DATA_WIDTH*4-1:0] outdata10,outdata11,outdata12,outdata13;
    wire[DATA_WIDTH*4-1:0] outdata20,outdata21,outdata22,outdata23;
    
    always@(*)begin
        case(col_count)
        2'b00:begin
            output_feature1[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*4-1:DATA_WIDTH*3];           
        end
        2'b01:begin
            output_feature1[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*4-1:DATA_WIDTH*3];           
        end
        2'b10:begin
            output_feature1[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata02[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata12[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata22[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*4-1:DATA_WIDTH*3];           
        end
        default:begin
            output_feature1[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*0+DATA_WIDTH-1-:DATA_WIDTH] = outdata03[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*1+DATA_WIDTH-1-:DATA_WIDTH] = outdata00[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*2+DATA_WIDTH-1-:DATA_WIDTH] = outdata01[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*3+DATA_WIDTH-1-:DATA_WIDTH] = outdata13[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*4+DATA_WIDTH-1-:DATA_WIDTH] = outdata10[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*5+DATA_WIDTH-1-:DATA_WIDTH] = outdata11[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*6+DATA_WIDTH-1-:DATA_WIDTH] = outdata23[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*7+DATA_WIDTH-1-:DATA_WIDTH] = outdata20[DATA_WIDTH*4-1:DATA_WIDTH*3];
            output_feature1[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH-1:0];output_feature2[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*2-1:DATA_WIDTH];output_feature3[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*3-1:DATA_WIDTH*2];output_feature4[DATA_WIDTH*8+DATA_WIDTH-1-:DATA_WIDTH] = outdata21[DATA_WIDTH*4-1:DATA_WIDTH*3];           
        end
    endcase
  end
    
    
    pixel_window_block pwb0_0(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data0),
        .ena(w00),
        .wea(w00),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata00),
        .enb(r00)
    );
        pixel_window_block pwb0_1(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data0),
        .ena(w01),
        .wea(w01),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata01),
        .enb(r01)
    );
        pixel_window_block pwb0_2(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data0),
        .ena(w02),
        .wea(w02),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata02),
        .enb(r02)
    );
        pixel_window_block pwb0_3(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data0),
        .ena(w03),
        .wea(w03),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata03),
        .enb(r03)
    );
        pixel_window_block pwb1_0(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data1),
        .ena(w10),
        .wea(w10),
        .addrb(input_channel_delay/4),
        .clkb(clk),
        .doutb(outdata10),
        .enb(r10)
    );
        pixel_window_block pwb1_1(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data1),
        .ena(w11),
        .wea(w11),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata11),
        .enb(r11)
    );
        pixel_window_block pwb1_2(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data1),
        .ena(w12),
        .wea(w12),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata12),
        .enb(r12)
    );
        pixel_window_block pwb1_3(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data1),
        .ena(w13),
        .wea(w13),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata13),
        .enb(r13)
    );
        pixel_window_block pwb2_0(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data2),
        .ena(w20),
        .wea(w20),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata20),
        .enb(r20)
    );
        pixel_window_block pwb2_1(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data2),
        .ena(w21),
        .wea(w21),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata21),
        .enb(r21)
    );
        pixel_window_block pwb2_2(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data2),
        .ena(w22),
        .wea(w22),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata22),
        .enb(r22)
    );
        pixel_window_block pwb2_3(
        .addra(input_channel_delay/4),
        .clka(clk),
        .dina(data2),
        .ena(w23),
        .wea(w23),
        .addrb(depth_channel_sel/4),
        .clkb(clk),
        .doutb(outdata23),
        .enb(r23)
     );
endmodule
