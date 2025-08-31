`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Pixel Window
// note that some of the signals are designed for timing&sequence issues, 
//which is to find the right time to make important changes, writes and reads.
//these signals are made through behavioral simulation and hard to understand

//////////////////////////////////////////////////////////////////////////////////
module pixel_window #(parameter DATA_WIDTH = 16, parameter PADDING = 1,parameter UPDATE_PARALLELISM = 4,parameter CHANNEL_PARALLELISM = 4)(
    input                                                   clk,
    //signals related to init layer window
    input                                                   init_buffer,
    input                                                   init_buffer_done,
    //basic params
    input[7:0]                                              input_size,
    input[7:0]                                              channel, 
    //depthwise computation current channel select
    input[7:0]                                              depth_channel_sel,  
    //first cycle of depthwise of last DCP channel conv
    input                                                   first_cycle,
    //enable one depthwise
    input                                                   depthwise_en,   
    //a col of data from layer window 
    input[DATA_WIDTH*UPDATE_PARALLELISM-1:0]                 data0,
    input[DATA_WIDTH*UPDATE_PARALLELISM-1:0]                 data1,
    input[DATA_WIDTH*UPDATE_PARALLELISM-1:0]                 data2,
    //update 4th col of pixel window. to address in layer window.  w is the col No. channel is the channel
    output reg[7:0]                                         input_w=0, 
    output reg[7:0]                                         input_channel=0, //in window channel
    //channel window data to DSU
    output reg[DATA_WIDTH*3*3*CHANNEL_PARALLELISM-1:0]      output_feature,
    //first pixel window done after init layer window
    output reg                                              first=0,
    //when update of the  4th col of pixel window is done 
    output reg                                              done=0
    );  
    
    //the update of 4th col in pixel window is not for current 3*3 depthwise, is for next, so en_count is to jump current one.
    //en_count is used below to indicate when the pixel window update is done for next 3*3 depthwise.
    reg                         en_count=0;
    always@(posedge clk)begin
        if(depthwise_en)begin
            en_count<=en_count+1;
        end
    end
   
   //inh is the current buffering row of the feature map
   reg[7:0]                     inh=0;
   //input window done is asserted when the inh at the last row and input_w at the last col of feature map including padding, 
   //which means no data needs to be input to pixel window
   reg                          input_window_done=0;
   
   //inh increment
   always@(posedge clk)begin
        if(init_buffer)begin
            inh<=0;
        end
        else if(input_window_done)begin
            inh<=inh;
        end
        else if(input_w==input_size-1+2*PADDING&&first_cycle)begin
           if(inh<input_size)begin
                  if(inh==input_size-1)begin
                        inh<=0;
                  end
                  else inh<=inh+1;
           end
        end
   end
   
   //indicates that a col of data is updated across all channels
   wire                         inputchannel_done;  
   assign inputchannel_done = ((input_channel==channel-UPDATE_PARALLELISM) || (channel<=UPDATE_PARALLELISM));
   
   //assert logic of input_window_done: when inh meets end of feature excluding PAD and input_w meets end of feature row including PAD
   //inh doesnt need PAD, because as above showed, inh increments after init 3 row of layer window 
   always@(posedge clk)begin
        if(input_w == input_size-1+2*PADDING &&inh==input_size-1&&first_cycle)
            input_window_done <= 1;
        if(init_buffer)begin
            input_window_done <= 0;
        end
   end
  
  //input_doing indicates when 4th col of pixel window is updating
   reg                          input_doing=0;
   //asserted when needs to init 3 col of pixel window at the row beginning
   reg                          init_window=0;
   //For delay reasons: bram read has 1 cycle delay
   //for timing reasons
   reg[7:0]                     inputw_delay=0;
   always@(posedge clk)begin
        inputw_delay<=input_w;
   end
   //when init 3 col of pixel window is finished
   wire                         init_window_done;
   assign init_window_done=(input_w==2&&inputchannel_done);
   
   //when updating/inputing the final col of a feature row, col is asserted, at this moment no need to update/input
   reg                          col_done = 0;
   always@(posedge clk)begin
        if(input_w==input_size-1+2*PADDING&&first_cycle)begin
            col_done<=1;
        end
        if(col_done&&first_cycle)begin
            col_done<=0;
        end
   end
   //to init pixel window at row beginning 
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
        else if(inputw_delay==0&&first_cycle)begin
            init_window<=1;
        end
        if(init_window_done)begin
            init_window<=0;
        end
   end
   //to show when the 4th pixel window col update for the next 3*3 depthwise is done 
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
      else if(!en_count&&first_cycle)begin
            done<=0;
      end
   end
   // first and rem are signals for timing&sequence issues,
   reg                          rem=0; 
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
   //like the layer window, pixel window has the same mechanism of rotating 4 columns to select 3
   reg[1:0]                     col_count=0;
   reg[2:0]                     col_sel[3:0];
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
   //control of input_doing signal which indicates the window col update is doing
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
   
   //input_channel increment, to select which channels of feature map are to be input
   always@(posedge clk)begin
        if(init_buffer)begin
            input_channel<=0;
        end
        if(input_window_done)begin
            input_channel<=0;
        end
        if(input_doing||init_window)begin
            if(channel<=UPDATE_PARALLELISM)begin
                input_channel<=0;
            end
            else if(input_channel<channel)begin
                if(input_channel==channel-UPDATE_PARALLELISM)begin
                    input_channel<=0;
                end
                else begin
                    input_channel<=input_channel+UPDATE_PARALLELISM;
                end
            end
        end
   end
   
    //input_w increment, to select which cols of feature map are to be input
   always@(posedge clk)begin
        if(init_buffer)begin
            input_w<=0;
        end
        else if(first_cycle&&channel<UPDATE_PARALLELISM)begin
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
        else if(channel>UPDATE_PARALLELISM&&inputchannel_done)begin
            if(input_w==input_size+2*PADDING-1)begin
                input_w<=0;
            end
            else input_w<=input_w+1;
        end
   end
   //designed for timing & sequence issues for window writing below
   reg                          input_doing_delay=0;
   always@(posedge clk)begin
        input_doing_delay<=input_doing;
   end
   reg[7:0]                     input_channel_delay=0;
   always@(posedge clk)begin
        input_channel_delay<=input_channel;
   end
   //pixel window   -- need more improvements here.
   // it is in the situation where UPDATE_PARALLELISM = CHANNEL_PARALLELISM, and if UPDATE_PARALLELISM != CHANNEL_PARALLELISM, it cannot work.
   // because the write port and read port width are fixed the same.
   //3 rows; 4 cols; for 4-channel data and the max input channel num across all conv layers is 32, so 32/4=8 unit in channel dimention
    reg[DATA_WIDTH*UPDATE_PARALLELISM-1:0]        window[2:0][3:0][32/UPDATE_PARALLELISM-1:0];
   integer                      ii,jj,kk;
   initial begin
         for(ii=0;ii<3;ii=ii+1)begin
             for(jj=0;jj<4;jj=jj+1)begin
                for(kk=0;kk<32/UPDATE_PARALLELISM;kk=kk+1)begin
                    window[ii][jj][kk] = 'b0;
                end
            end
         end
   end

    // update the 4th col of pixel window
    always@(posedge clk)begin
        if(init_window&&inputw_delay==0)begin
            window[0][col_sel[0]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[0]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[0]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end
        else if(init_window&&inputw_delay==1)begin
            window[0][col_sel[1]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[1]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[1]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end
        else if(init_window&&inputw_delay==2)begin
            window[0][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end        
        else if(first)begin
            window[0][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end
        else if(inputw_delay==2&&input_doing)begin
            window[0][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[2]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end
        else if(input_doing_delay)begin
            window[0][col_sel[3]][input_channel_delay/UPDATE_PARALLELISM] <= data0;
            window[1][col_sel[3]][input_channel_delay/UPDATE_PARALLELISM] <= data1;
            window[2][col_sel[3]][input_channel_delay/UPDATE_PARALLELISM] <= data2;
        end
    end
    
    //reorganzition in channel window 
    integer                     i,j,k;
    always@(posedge clk)begin
        for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
            for(j=0;j<3;j=j+1)begin
                for(k=0;k<3;k=k+1)begin
                    output_feature[(i*3*3+j*3+k)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] <= window[j][col_sel[k]][depth_channel_sel/CHANNEL_PARALLELISM][DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH];
                end
            end
        end
    end    
endmodule
