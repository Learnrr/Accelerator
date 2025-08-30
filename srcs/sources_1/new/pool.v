`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/02 16:56:08
// Design Name: 
// Module Name: pool
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


module pool #(parameter DATA_WIDTH=16)(
    input clk,
    input en,
    input[7:0] input_size,
    input[7:0] channel,
    input[DATA_WIDTH*8*2-1:0] infeature,
    (*max_fanout=5*)output reg[DATA_WIDTH*8-1:0] outfeature,
    output reg[7:0] outh,
    output reg[7:0] outw,
    output reg[7:0] inw,
    output reg[7:0] channel_sel,
    output reg pool_doing,
    output channel_done,
    output reg done_delay2=0
    );
    reg[7:0] inh;
    reg started;
    always@(posedge clk)begin
        if(en) started <= 1;
        if(channel_done) started<=0;
    end

    always@(posedge clk)begin
        pool_doing<=started;
    end
    assign channel_done =(channel_sel>=channel-8||channel<=8);
    assign done = outh==input_size/2 -1 &&outw==input_size/2 -1 &&channel_done;
    reg done_delay=0;
    always@(posedge clk)begin//delay one cycle to ensure layer changed one cylce later
        done_delay<=done;//if not set, layer changed quickly when pool done, and pool outfeature is written to the wrong place of BRAM0 in TOP module
    end
    always@(posedge clk)begin
        done_delay2<=done_delay;
    end
   initial begin
        outh = 0;
        outw = 0;
        inh=0;
        inw=0;
        channel_sel=0;
        started = 0;
   end
    
    genvar i,k;
    wire[DATA_WIDTH*2-1:0] inputs[7:0];
    wire[DATA_WIDTH-1:0] result[7:0];
    generate
        for(i=0;i<8;i=i+1)begin
            assign inputs[i] = infeature[DATA_WIDTH*2*i+DATA_WIDTH*2-1 -: DATA_WIDTH*2];
        end
    endgenerate

    max_pool pool1(inputs[0][DATA_WIDTH-1:0],inputs[0][DATA_WIDTH*2-1:DATA_WIDTH],result[0]);
    max_pool pool2(inputs[1][DATA_WIDTH-1:0],inputs[1][DATA_WIDTH*2-1:DATA_WIDTH],result[1]);
    max_pool pool3(inputs[2][DATA_WIDTH-1:0],inputs[2][DATA_WIDTH*2-1:DATA_WIDTH],result[2]);
    max_pool pool4(inputs[3][DATA_WIDTH-1:0],inputs[3][DATA_WIDTH*2-1:DATA_WIDTH],result[3]);
    max_pool pool5(inputs[4][DATA_WIDTH-1:0],inputs[4][DATA_WIDTH*2-1:DATA_WIDTH],result[4]);
    max_pool pool6(inputs[5][DATA_WIDTH-1:0],inputs[5][DATA_WIDTH*2-1:DATA_WIDTH],result[5]);
    max_pool pool7(inputs[6][DATA_WIDTH-1:0],inputs[6][DATA_WIDTH*2-1:DATA_WIDTH],result[6]);
    max_pool pool8(inputs[7][DATA_WIDTH-1:0],inputs[7][DATA_WIDTH*2-1:DATA_WIDTH],result[7]);
    //to 2 layer pool buffer
    always@(posedge clk)begin
        if(channel_done)begin
            if(inw<input_size/2)begin              
                if(inw == input_size/2-1)begin
                    if(inh<2)begin
                        if(inh == 1)begin
                            inh <= 0;
                        end
                        else inh <= inh+1;
                    end
                    else inh<=0;
                    inw<=0;
                end
                else inw <= inw + 1;               
             end
             else inw<=0;
        end
        else begin
            inh<=inh;
            inw<=inw;
        end
    end
    always@(posedge clk)begin
           if(en)begin
                channel_sel<=0;
            end
          //  else if(wait_clk>1) channel_sel<=0;
            else if(channel_done) channel_sel<=0;
            else if(started&&channel_sel<channel-8)
                channel_sel <= channel_sel + 8;
            else begin
                channel_sel <= 0;
            end
    end
 
   
    // write to pool buffer
    reg[7:0] inh_delay=0;
    always@(posedge clk)begin
        inh_delay<=inh;
    end
    
    wire[DATA_WIDTH*8-1:0] buffer_outdata;
    wire[6:0] buf_outaddr;
    reg[6:0] buf_inaddr;
    assign buf_outaddr=8*inw+channel_sel/8;
    always@(posedge clk)begin
        buf_inaddr<=buf_outaddr;
    end
   
    reg[DATA_WIDTH*8-1:0] buffer_indata;
    integer j;
    always@(*)begin
        if(pool_doing)begin
            for(j=0;j<8;j=j+1)begin
                buffer_indata[DATA_WIDTH*j+DATA_WIDTH-1 -: DATA_WIDTH] <= inh_delay==0?result[j]:0;
            end
        end
    end
    pool_buffer pool_buffer(
        .addra(buf_inaddr),
        .clka(clk),
        .dina(buffer_indata),
        .ena(inh_delay==0&&pool_doing),
        .wea(inh_delay==0&&pool_doing),
        .addrb(buf_outaddr),
        .clkb(clk),
        .doutb(buffer_outdata),
        .enb(started&&inh==1)
    );
     wire[DATA_WIDTH-1:0] result_h[7:0];
    always@(posedge clk)begin
        for(j=0;j<8;j=j+1)begin
            outfeature[DATA_WIDTH*j+DATA_WIDTH-1 -: DATA_WIDTH] <= inh_delay==0?0:result_h[j];
        end
    end
    
    max_pool pool11(buffer_outdata[DATA_WIDTH*0+DATA_WIDTH-1 -: DATA_WIDTH],result[0],result_h[0]);
    max_pool pool22(buffer_outdata[DATA_WIDTH*1+DATA_WIDTH-1 -: DATA_WIDTH],result[1],result_h[1]);
    max_pool pool33(buffer_outdata[DATA_WIDTH*2+DATA_WIDTH-1 -: DATA_WIDTH],result[2],result_h[2]);
    max_pool pool44(buffer_outdata[DATA_WIDTH*3+DATA_WIDTH-1 -: DATA_WIDTH],result[3],result_h[3]);
    max_pool pool55(buffer_outdata[DATA_WIDTH*4+DATA_WIDTH-1 -: DATA_WIDTH],result[4],result_h[4]);
    max_pool pool66(buffer_outdata[DATA_WIDTH*5+DATA_WIDTH-1 -: DATA_WIDTH],result[5],result_h[5]);
    max_pool pool77(buffer_outdata[DATA_WIDTH*6+DATA_WIDTH-1 -: DATA_WIDTH],result[6],result_h[6]);
    max_pool pool88(buffer_outdata[DATA_WIDTH*7+DATA_WIDTH-1 -: DATA_WIDTH],result[7],result_h[7]);
    
//     //2 layer pool buffer
//    reg[15:0] buffer[63:0][15:0];
//    always@(posedge clk)begin
//        if(pool_doing)begin// pool write ena
//            if(inh_delay==1)begin
//            //select max one
//        outfeature[16*0+15 -: 16] <= buffer[channel_sel+0][inw][15]==result[0][15]&&buffer[channel_sel+0][inw][15]==1?{buffer[channel_sel+0][inw][14:0]<result[0][14:0]?buffer[channel_sel+0][inw][15:0]:result[0][15:0]}:buffer[channel_sel+0][inw][15]==result[0][15]&&buffer[channel_sel+0][inw][15]==0?{buffer[channel_sel+0][inw][14:0]>result[0][14:0]?buffer[channel_sel+0][inw][15:0]:result[0][15:0]}:buffer[channel_sel+0][inw][15]>result[0][15]?result[0]:buffer[channel_sel+0][inw];
//        outfeature[16*1+15 -: 16] <= buffer[channel_sel+1][inw][15]==result[1][15]&&buffer[channel_sel+1][inw][15]==1?{buffer[channel_sel+1][inw][14:0]<result[1][14:0]?buffer[channel_sel+1][inw][15:0]:result[1][15:0]}:buffer[channel_sel+1][inw][15]==result[1][15]&&buffer[channel_sel+1][inw][15]==0?{buffer[channel_sel+1][inw][14:0]>result[1][14:0]?buffer[channel_sel+1][inw][15:0]:result[1][15:0]}:buffer[channel_sel+1][inw][15]>result[1][15]?result[1]:buffer[channel_sel+1][inw];
//        outfeature[16*2+15 -: 16] <= buffer[channel_sel+2][inw][15]==result[2][15]&&buffer[channel_sel+2][inw][15]==1?{buffer[channel_sel+2][inw][14:0]<result[2][14:0]?buffer[channel_sel+2][inw][15:0]:result[2][15:0]}:buffer[channel_sel+2][inw][15]==result[2][15]&&buffer[channel_sel+2][inw][15]==0?{buffer[channel_sel+2][inw][14:0]>result[2][14:0]?buffer[channel_sel+2][inw][15:0]:result[2][15:0]}:buffer[channel_sel+2][inw][15]>result[2][15]?result[2]:buffer[channel_sel+2][inw];
//        outfeature[16*3+15 -: 16] <= buffer[channel_sel+3][inw][15]==result[3][15]&&buffer[channel_sel+3][inw][15]==1?{buffer[channel_sel+3][inw][14:0]<result[3][14:0]?buffer[channel_sel+3][inw][15:0]:result[3][15:0]}:buffer[channel_sel+3][inw][15]==result[3][15]&&buffer[channel_sel+3][inw][15]==0?{buffer[channel_sel+3][inw][14:0]>result[3][14:0]?buffer[channel_sel+3][inw][15:0]:result[3][15:0]}:buffer[channel_sel+3][inw][15]>result[3][15]?result[3]:buffer[channel_sel+3][inw];
//        outfeature[16*4+15 -: 16] <= buffer[channel_sel+4][inw][15]==result[4][15]&&buffer[channel_sel+4][inw][15]==1?{buffer[channel_sel+4][inw][14:0]<result[4][14:0]?buffer[channel_sel+4][inw][15:0]:result[4][15:0]}:buffer[channel_sel+4][inw][15]==result[4][15]&&buffer[channel_sel+4][inw][15]==0?{buffer[channel_sel+4][inw][14:0]>result[4][14:0]?buffer[channel_sel+4][inw][15:0]:result[4][15:0]}:buffer[channel_sel+4][inw][15]>result[4][15]?result[4]:buffer[channel_sel+4][inw];
//        outfeature[16*5+15 -: 16] <= buffer[channel_sel+5][inw][15]==result[5][15]&&buffer[channel_sel+5][inw][15]==1?{buffer[channel_sel+5][inw][14:0]<result[5][14:0]?buffer[channel_sel+5][inw][15:0]:result[5][15:0]}:buffer[channel_sel+5][inw][15]==result[5][15]&&buffer[channel_sel+5][inw][15]==0?{buffer[channel_sel+5][inw][14:0]>result[5][14:0]?buffer[channel_sel+5][inw][15:0]:result[5][15:0]}:buffer[channel_sel+5][inw][15]>result[5][15]?result[5]:buffer[channel_sel+5][inw];
//        outfeature[16*6+15 -: 16] <= buffer[channel_sel+6][inw][15]==result[6][15]&&buffer[channel_sel+6][inw][15]==1?{buffer[channel_sel+6][inw][14:0]<result[6][14:0]?buffer[channel_sel+6][inw][15:0]:result[6][15:0]}:buffer[channel_sel+6][inw][15]==result[6][15]&&buffer[channel_sel+6][inw][15]==0?{buffer[channel_sel+6][inw][14:0]>result[6][14:0]?buffer[channel_sel+6][inw][15:0]:result[6][15:0]}:buffer[channel_sel+6][inw][15]>result[6][15]?result[6]:buffer[channel_sel+6][inw];
//        outfeature[16*7+15 -: 16] <= buffer[channel_sel+7][inw][15]==result[7][15]&&buffer[channel_sel+7][inw][15]==1?{buffer[channel_sel+7][inw][14:0]<result[7][14:0]?buffer[channel_sel+7][inw][15:0]:result[7][15:0]}:buffer[channel_sel+7][inw][15]==result[7][15]&&buffer[channel_sel+7][inw][15]==0?{buffer[channel_sel+7][inw][14:0]>result[7][14:0]?buffer[channel_sel+7][inw][15:0]:result[7][15:0]}:buffer[channel_sel+7][inw][15]>result[7][15]?result[7]:buffer[channel_sel+7][inw];


//            end
//            else begin
//                outfeature[15:0] <= 0;
//                outfeature[31:16] <= 0;
//                outfeature[47:32] <= 0;
//                outfeature[63:48] <= 0;
//                outfeature[79:64] <= 0;
//                outfeature[95:80] <= 0;
//                outfeature[111:96] <= 0;
//                outfeature[127:112] <= 0;
                
//                buffer[channel_sel+0][inw] <= result[0];
//                buffer[channel_sel+1][inw] <= result[1];
//                buffer[channel_sel+2][inw] <= result[2];
//                buffer[channel_sel+3][inw] <= result[3];
//                buffer[channel_sel+4][inw] <= result[4];
//                buffer[channel_sel+5][inw] <= result[5];
//                buffer[channel_sel+6][inw] <= result[6];
//                buffer[channel_sel+7][inw] <= result[7];
//            end
//        end
//    end
    // output position out h w
    always@(posedge clk)begin
        if(inh==1)begin
            if(channel_done)begin
                if(outw<input_size/2)begin
                    if(outw==input_size/2-1)begin
                        outw<=0;
                        if(outh<input_size/2)begin
                            if(outh==input_size/2-1)begin
                                outh<=0;
                            end
                            else outh<=outh+1;
                        end
                        else outh<=0;
                    end
                    else outw<=outw+1;
                end
                else outw<=0;
            end
        end
        else begin
            outw<=outw;
            outh<=outh;
        end
    end
    
endmodule
