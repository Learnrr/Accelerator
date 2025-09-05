`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Pointwise Convoluion Unit
// 
//////////////////////////////////////////////////////////////////////////////////


module pointwise #(parameter DATA_WIDTH = 16, parameter INCHANNEL_PARALLELISM = 8, parameter OUTCHANNEL_PARALLELISM = 8)(
    input                                                               clk,
    input                                                               en,
    //update 4th col of pixel window done, used in this module to reset next_en
    input                                                               update_window_done,
    //basic params from cu
    input[7:0]                                                          output_size,
    input[7:0]                                                          input_channel,
    input[7:0]                                                          output_channel, 
    input[3:0]                                                          layer,
    //inputs and outputs
    input[DATA_WIDTH*1*1*INCHANNEL_PARALLELISM-1:0]                     input_feature,
    input[DATA_WIDTH*INCHANNEL_PARALLELISM*OUTCHANNEL_PARALLELISM-1:0]  input_weight,
    output [DATA_WIDTH*1*1*OUTCHANNEL_PARALLELISM-1:0]                  output_feature,
    //output position
    output reg[7:0]                 out_h,
    output reg[7:0]                 out_w,
    //current channel sel
    output reg[7:0]                 input_channel_sel,
    output reg[7:0]                 output_channel_sel,
    //channel sel 3 cycles ago
    output [7:0]                    input_channel_sel_delay3,
    output [7:0]                    output_channel_sel_delay3,    
    //channel done
    output wire                     point_11_channel_done,
    //3 cycles after channel selection done ,i.e. computation of 1*1 pointwise is done
    output wire                     point11_done,
    //signal to start next depthwise
    output reg                      next_en = 0,
    //for write enable in intermediate buffer2(P2P buffer)
    output reg                      point_doing=0,
    //pointwise of whole feature is done 
    output                          done
    );
    //whole feature pointwise is done
    assign done = out_w==output_size-1&&out_h==output_size-1&&point11_done;
    
    // current selected channel is done
    wire                            output_channel_done,input_channel_done;
    //if computation process is started
    reg                             started = 0;  
    always@(posedge clk)begin
        if(layer<4&&point_11_channel_done)              started <= 0;
        if(layer>=4&&layer<8&&point_11_channel_done)    started <= 0;
        if(layer>=8&&point_11_channel_done)             started <= 0;
        if(en)                                          started <= 1;
    end    
    //point doing for write enable signal at intermediate buffer2 
     always@(posedge clk)begin
        if(started)                 point_doing <= 1;
        else                        point_doing <= 0;
    end

    //for right bias rom address
    reg[7:0]                        poc_sel=0;
    always@(posedge clk)begin
        poc_sel<=output_channel_sel_delay3;
    end
    reg[7:0]                        pic_sel=0;
    always@(posedge clk)begin
        pic_sel<=input_channel_sel_delay3;
    end
    
    //pipeline: when to start next depthwise(for situation where point time longer than depth)
    //for diff networks, it needs to be adjusted
    always@(posedge clk)begin
        if(done)begin
            next_en <= 0;
        end
        else if(layer<4 && output_channel_sel==8'h00 && started)begin
            next_en <= 1;
        end 
        else if(layer>=4 && layer<8 && output_channel_sel==8'h00 && input_channel_sel==8'h10)begin
            next_en <= 1;
        end
        else if(layer>=8 && layer<12 && output_channel_sel==8'h20 && input_channel_sel==8'h10)begin
            next_en <= 1;
        end
        else if(update_window_done)begin
            next_en <= 0;
        end
    end

   //bias rom 
    (*ram_style="block"*)
    reg[DATA_WIDTH*2-1:0]           bias[127:0];
    initial begin
        input_channel_sel = 0;
        output_channel_sel = 0;
        out_h = 0;
        out_w = 0;
        $readmemb("../../../../../weights/point_bias.txt",bias);
    end 
    
    //pack one-dim input to 2-dim
    wire[DATA_WIDTH-1:0]           inweight[OUTCHANNEL_PARALLELISM-1:0][INCHANNEL_PARALLELISM-1:0];
    //input_weight is the first step of weight organization, the following generate is to organize inweight to turn to input-weight
    genvar i,j,k;
    generate
        for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
            for(j=0;j<INCHANNEL_PARALLELISM;j=j+1)begin
                assign inweight[OUTCHANNEL_PARALLELISM-1-i][INCHANNEL_PARALLELISM-1-j] = input_weight[(i*INCHANNEL_PARALLELISM+j)*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    endgenerate

    //second step of weight organization
    wire[DATA_WIDTH*INCHANNEL_PARALLELISM-1:0] weight_block_line[OUTCHANNEL_PARALLELISM-1:0];
    generate 
        for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
            for(j=0;j<INCHANNEL_PARALLELISM;j=j+1)begin
                assign weight_block_line[i][j*DATA_WIDTH+DATA_WIDTH-1 -: DATA_WIDTH] = inweight[i][j];
            end
        end
    endgenerate

    //input channel done
     assign input_channel_done = started&&(input_channel<=INCHANNEL_PARALLELISM||input_channel_sel>=input_channel-INCHANNEL_PARALLELISM);
    //output channel done
     assign output_channel_done = started&&(output_channel<=OUTCHANNEL_PARALLELISM||output_channel_sel>=output_channel-OUTCHANNEL_PARALLELISM);
     //current channel select done
     assign point_11_channel_done = input_channel_done&&output_channel_done;
     //true 1*1 point is done
     //there is diff between point_11_channel_done and point11_done because after channel sel, point needs several pipeline stages to finish
     assign point11_done = (layer<4&&output_channel_sel_delay3==8'h18)
     ||(layer<8&&layer>=4&&output_channel_sel_delay3==8'h18&&input_channel_sel_delay3==8'h18)
     ||(layer>=8&&output_channel_sel_delay3==8'h38&&input_channel_sel_delay3==8'h18);
     
     //increment logic of inchannel sel
    always@(posedge clk)begin
            if(en)                                              input_channel_sel <= 0;
            else if(input_channel_done)                         input_channel_sel <= 0;
            else if(started&&input_channel_sel<input_channel-8) input_channel_sel <= input_channel_sel + INCHANNEL_PARALLELISM;
    end
    //inc logic of outchannel sel
    always@(posedge clk)begin
        if(en)                                                                      output_channel_sel<=0;
        else if(done)                                                               output_channel_sel<=0;
        else if(output_channel_done&&input_channel_done)                            output_channel_sel<=0;
        else if(input_channel_done&&started&&output_channel_sel<output_channel-8)   output_channel_sel<=output_channel_sel+OUTCHANNEL_PARALLELISM;
        else if(input_channel_done)                                                 output_channel_sel<=0;
    end

    wire[DATA_WIDTH*2-1:0]         result[OUTCHANNEL_PARALLELISM-1:0];
    // select one channel_sel_delay3 from 8(OCP) ones
    wire[7:0]                      output_channel_sel_delay3_copy[OUTCHANNEL_PARALLELISM-1:0];
    wire[7:0]                      input_channel_sel_delay3_copy[OUTCHANNEL_PARALLELISM-1:0];
    assign output_channel_sel_delay3 = output_channel_sel_delay3_copy[0];
    assign input_channel_sel_delay3 = input_channel_sel_delay3_copy[0];    
            
    //8*8 compute
    generate
        for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
            compute_engine_p 
            #( 
            .DATA_WIDTH(DATA_WIDTH),  
            .INCHANNEL_PARALLELISM(INCHANNEL_PARALLELISM),  
            .OUTCHANNEL_PARALLELISM(OUTCHANNEL_PARALLELISM)
            )
            com
            (clk,
            input_channel_sel,
            output_channel_sel,
            input_feature,
            weight_block_line[i],
            result[i],
            input_channel_sel_delay3_copy[i],
            output_channel_sel_delay3_copy[i]);
        end
    endgenerate
    
    //outputs with bias
    wire[DATA_WIDTH*2-1:0]          result_bias[OUTCHANNEL_PARALLELISM-1:0];
   //diff layer has diff base addr, because biases of diff layers in the same memory   
    wire[7:0]                       base_addr;
    assign base_addr = layer<4?0:(layer<8?32:64);    
    
    //diff outputchannel add diff bias
    wire[7:0]                       bias_addr[OUTCHANNEL_PARALLELISM-1:0];
    generate for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
        assign bias_addr[i] = base_addr+poc_sel+i;
    end
    endgenerate
    //one output channel only add bias once, if pic_sel==0, it's the first time; if >0 , bias has been added.
    //in this case, let adder result_bias = result
    generate for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
        adder #(.DATA_WIDTH(DATA_WIDTH))adder(pic_sel>0,result[i],bias[bias_addr[i]],result_bias[i]);
    end
    endgenerate
    
    //results with bias and quantization
    wire[DATA_WIDTH*2-1:0]          result_quan[OUTCHANNEL_PARALLELISM-1:0];
    //diff layer has diff quantization scale, need to shift diff    
    wire[7:0]                       shift_num;
    assign shift_num = layer<4?14:(layer<8?15:14);    
    
    generate for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
         assign result_quan[i] = {result_bias[i][DATA_WIDTH*2-1],result_bias[i][DATA_WIDTH*2-2:0]>>shift_num};
    end
    endgenerate
    
    //output with bias and quantization and trunction
    generate for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
        assign output_feature[DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH] = {result_quan[i][DATA_WIDTH*2-1],result_quan[i][DATA_WIDTH-2:0]};        
    end
    endgenerate
   
      //output position
    always@(posedge clk)begin
        if(done)begin
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
          
endmodule
