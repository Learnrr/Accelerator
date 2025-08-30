`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description:  Depthwise Convolution Unit
// this module convolutes DCP channels of data from channel window.
// 
//////////////////////////////////////////////////////////////////////////////////

module depthwise #(parameter DATA_WIDTH = 16,parameter KERNEL_SIZE = 3,parameter CHANNEL_PARALLELISM = 4)(
    input                                                                clk,
    //'en'  is to start a new 3*3 data block depthwise
    input                                                                en,
    //when initing buffer, signals in this module cannot change
    input                                                               init_buffer,
    //basic params from cu
    input[7:0]                                                          input_size,
    input[7:0]                                                          output_size,
    input[7:0]                                                          channel, 
    input[3:0]                                                          layer,
    //inputs
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE*CHANNEL_PARALLELISM-1:0]  input_feature,//channel-wise 
    input [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE*CHANNEL_PARALLELISM-1:0]  input_weight,//
    //outputs
    output[DATA_WIDTH*1*1*CHANNEL_PARALLELISM-1:0]                      output_feature,
    //current processing channels, if it's 4 and DCP is 4, 4-8 channels are in process
    output reg[7:0]                                                     channel_sel=0,
    //channel select, delay 3 cycles, to address the intermediate buffer to write
    //pipeline stage is 4, outputs now is the outputs 4 cycles ago, so the address need to be 4 cycles ago
    output[7:0]                                                         channel_sel_delay3,
    
    output reg                                                          first_cycle=0,
    output                                                              depth33_done,    
    output                                                              layer_done,
    output                                                              done
    );
   //when depthwise selected channel meets the end. current channel sel, not delayed channel sel
    wire                                            channel_done;
   //one cycle later than delayed channel sel, to address bias, from sequential logic to combinational logic
    reg[7:0]                                        dep_sel=0;
    always@(posedge clk)begin
        dep_sel<=channel_sel_delay3;
    end
    //bias
    (*ram_style = "block"*)
    reg[DATA_WIDTH*2-1:0]                           bias[66:0];
    initial begin
       $readmemb("D:/weights/depth_bias.txt",bias);
    end
    // depthwise position
    reg[7:0]                                        h=0,w=0;
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
    //one row of feature depthwise done
    assign layer_done = w==input_size-1 && first_cycle;
    
    //if it's doing
    reg                                             started = 0;   
    always@(posedge clk)begin
        if(en&&!init_buffer) started <= 1;
        else if(depth33_done) started<=0;
    end       

  //the first computing cycle of the last DCP channels
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
    
    //get separate 1£¬2£¬3...4(DCP) channel of 3*3 data    
    wire[DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0]    inputs[CHANNEL_PARALLELISM-1:0];    
    genvar                                          i;
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        assign inputs[i] = input_feature[i*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];        
    end
    endgenerate

    //get separate 1£¬2£¬3£¬4  channel of 3*3 weight
    wire[DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0]   weights[CHANNEL_PARALLELISM-1:0];
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        assign weights[i] = input_weight[i*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH+KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
    end
    endgenerate
    
    //4(DCP) channels of 3*3 window result
    wire[DATA_WIDTH*2-1:0]                          result[CHANNEL_PARALLELISM-1:0];
    //if compututation is done
    wire                                            com_done[CHANNEL_PARALLELISM-1:0];   
    //timing  
    wire[7:0]                                       channel_sel_delay3_copy[CHANNEL_PARALLELISM-1:0];
    assign channel_sel_delay3 = channel_sel_delay3_copy[0];
    
    //4 compute engines work parallelly 
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        compute_engine 
        #(
        .DATA_WIDTH(DATA_WIDTH)
        )
        com(clk,
        en,
        channel_done,
        started,
        channel_sel,
        inputs[i],
        weights[i],
        result[i],
        channel_sel_delay3_copy[i],
        com_done[i]
        );
    end
    endgenerate
    
    //selected channel done
    assign channel_done = started&&(channel_sel>=channel-CHANNEL_PARALLELISM||channel<=CHANNEL_PARALLELISM);
    //3*3 block depth done
    assign depth33_done = channel_done&&com_done[0];
   
       //channel select
    always@(posedge clk)begin
           if(en)                                                        channel_sel <= 0;
           else if(channel<=CHANNEL_PARALLELISM)                         channel_sel <= 0;
           else if(depth33_done)                                         channel_sel <= 0;
           else if((started&&channel_sel<channel-CHANNEL_PARALLELISM))   channel_sel <= channel_sel + CHANNEL_PARALLELISM;
           else if(channel_done&&com_done[0])                            channel_sel <= 0;
    end
    
    //post process -- add bias, quantization, trunctation
    //conv result with bias
    wire[DATA_WIDTH*2-1:0]                          result_bias[CHANNEL_PARALLELISM-1:0];
    
    //diff layer has diff base addr, because biases of diff layers in the same memory
    wire[7:0]                                       base_addr;
    assign base_addr = layer<4?0:(layer<8?3:35);
    
    //get the offset in bias rom
    wire[7:0]                                       bias_addr[CHANNEL_PARALLELISM-1:0];
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        assign bias_addr[i] = base_addr + dep_sel+i;
    end
    endgenerate
    
    //add bias
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        adder #(.DATA_WIDTH(DATA_WIDTH))adder(channel<i+1,result[i],bias[bias_addr[i]],result_bias[i]);
    end
    endgenerate
    
    //quantization
    wire[DATA_WIDTH*2-1:0]                          result_quan[CHANNEL_PARALLELISM-1:0];
    //diff layer has diff quantization scale, need to shift diff
    wire[7:0]                                       shift_num;
    assign shift_num = layer<4?15:(layer<8?15:16);
    
    //result with bias and quantization
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        assign result_quan[i] = {result_bias[i][DATA_WIDTH*2-1],result_bias[i][DATA_WIDTH*2-2:0]>>shift_num};
    end
    endgenerate    
    
    //result with bias, quantization and truncation 
    generate for(i=0;i<CHANNEL_PARALLELISM;i=i+1)begin
        assign output_feature[DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[i][DATA_WIDTH*2-1],result_quan[i][DATA_WIDTH-2:0]};
    end
    endgenerate        

endmodule
