`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Depthwise Separable Convolution Unit
// 
//////////////////////////////////////////////////////////////////////////////////

module DSU #(
    parameter DATA_WIDTH = 16, 
    parameter CHANNEL_PARALLELISM = 4, 
    parameter INCHANNEL_PARALLELISM = 8, 
    parameter OUTCHANNEL_PARALLELISM = 8)(
    input                                               clk,
    //comes from control unit DSU_en
    input                                               en,
    //when initing layer window, DSU is off 
    input                                               init_buffer,
    //pixel window update is done, signal to start a new 3*3depthwise 
    input                                               window_done,
    //the first initing pixel window is done, comes from first in pixel window and first_window_done in TOP 
    input                                               init,
    //from cu, to enable depthwise and pointwise
    input                                               depth_en,
    input                                               point_en,
    //basic params from cu
    input[3:0]                                          layer,
    input[7:0]                                          input_size,
    input[7:0]                                          output_size,
    input[7:0]                                          input_channel,
    input[7:0]                                          output_channel,
    //inputs
    input[DATA_WIDTH*3*3*CHANNEL_PARALLELISM-1:0]       depth_infeature,
    
    output[7:0]                                         depth_channel_sel,
    //first cycle of processing the last DCP channel
    output                                              first_cycle,
    //3*3 data block of depthwise is done
    output                                              depth33_done,
    //point channel, used to address intermediate buffer2(P2P buffer)
    output[7:0]                                         point_input_channel_sel_delay3,
    output[7:0]                                         point_output_channel_sel_delay3,
    //signal to start a new depthwise
    output                                              depthwise_en,    
    //DSU outputs, pointwise outputs
    output[DATA_WIDTH*OUTCHANNEL_PARALLELISM-1:0]       outfeature,
    //a data block of pointwise is done
    output                                              point11_done,
    //when point is doing, used to indicate when write is enable for intermediate buffer2
    output                                              point_doing,
    //when a feature-row of depthwise is done, needs to switch to next row
    output                                              depth_layer_done,
    //a whole feature's depth/point is done
    output                                              depth_done,
    output                                              point_done
    );
    
    //depthwise
    //diff conv layer has diff base addr in weight rom
    wire[4:0]                                                               depth_base_addr;
    assign depth_base_addr = layer<4?5'd0:(layer<8?5'd1:(layer<12?5'd9:5'd0));
    //to address depthwise weight in weight rom   
    wire[4:0]                                                               depth_weight_addr;
    assign depth_weight_addr = depth_base_addr+depth_channel_sel/CHANNEL_PARALLELISM;
    //depthwise weight per DCP channels
    wire[DATA_WIDTH*3*3*CHANNEL_PARALLELISM-1:0]                            depth_inweight;
    //depthwise selected channel and is delayed 3 cycles because pipeline stage is 4, 
    //used to be address to write intermediate buffer(D2P buffer) 
    wire[7:0]                                                               depth_channel_sel_delay3;
    //depth outputs
    wire[DATA_WIDTH*CHANNEL_PARALLELISM-1:0]                                depth_outfeature;   
    
    
    //when the data in D2P buffer is ready for pointwise
    wire                                                                    ib_done;
    
    //pointwise
    //pointwise output position -- not used   
    wire[7:0]                                                               outh,outw;
    //when to start a new pointwise
    wire                                                                    pointwise_en;
    wire[DATA_WIDTH*INCHANNEL_PARALLELISM-1:0]                             point_infeature;    
    //to address the D2P buffer for pointwise inputs
    wire[7:0]                                                               point_input_channel_sel,point_output_channel_sel;
    
    wire                                                                    point11_channel_done;
    //similar to depthwise
    wire[7:0]                                                               point_base_addr;
    assign point_base_addr = layer<4?8'd0:(layer<8?8'd4:(layer<12?8'd20:8'd0));
    wire[7:0]                                                               point_weight_addr;
    assign point_weight_addr = point_base_addr+(point_output_channel_sel/OUTCHANNEL_PARALLELISM)*((input_channel<INCHANNEL_PARALLELISM?INCHANNEL_PARALLELISM:input_channel)/INCHANNEL_PARALLELISM)+point_input_channel_sel/INCHANNEL_PARALLELISM;
    wire[DATA_WIDTH*OUTCHANNEL_PARALLELISM*INCHANNEL_PARALLELISM-1:0]       point_inweight;     
    //signal that can start next 3*3 depthwise  
    wire                                                                    next_en;
    
    //select appropriate time to start depth/point
    reg                                                                     depth33_done_delay=0;
    always@(posedge clk)begin
        if(depth33_done)
            depth33_done_delay<=1;
        if(first_cycle)begin
            depth33_done_delay<=0;
        end
    end
    assign pointwise_en = point_en&&en&&ib_done;
    assign depthwise_en = depth_en&&en&&(init||window_done&&(layer<4&&depth33_done||layer>=4&&depth33_done_delay&&next_en));
        
    depth_weight_rom depth_weight_rom(
        .addra(depth_weight_addr),
        .clka(clk),
        .douta(depth_inweight)
    );
    //depthwise unit
    depthwise 
    #(
     .DATA_WIDTH(DATA_WIDTH), 
     .KERNEL_SIZE(3), 
     .CHANNEL_PARALLELISM(CHANNEL_PARALLELISM)
    )
    dw(
    //input port
        clk,
        //enable
        depthwise_en,
        //when initing layer window, some signals in depthwise cannot change. 
        init_buffer,
        //params
        input_size,
        output_size,
        input_channel,
        layer,
        //inputs
        depth_infeature,
        depth_inweight,
   //output port
        depth_outfeature,
        //current selected channel which is to be processed, is used to address input data in weight rom and channel window
        depth_channel_sel,
        //delayed selected channel, is used to address D2P buffer to write in
        depth_channel_sel_delay3,        
        //the first cycle of last DCP channels that are in processing. used to signal other events
        first_cycle,        
        //3*3 data block of depthwise is done 
        depth33_done,
        // depthwise of a row of feature map is done
        depth_layer_done,
        //whole feature map's depthwise is done
        depth_done
    );

    point_weight_rom point_weight_rom(
        .addra(point_weight_addr),
        .clka(clk),
        .douta(point_inweight)
    );
    //D2P buffer
    intermediate_buffer 
    #(
     .DATA_WIDTH(DATA_WIDTH),
     .CHANNEL_PARALLELISM(CHANNEL_PARALLELISM), 
     .INCHANNEL_PARALLELISM(INCHANNEL_PARALLELISM)
    )
    ib(
    //input port
        clk,
        layer,
        depth_channel_sel_delay3,
        point_input_channel_sel,
        point11_channel_done,
        depth33_done,
        depth_outfeature,
     //output port
        point_infeature,
        ib_done      
    );
    //pointwise unit
    pointwise 
    #(
     .DATA_WIDTH(DATA_WIDTH),  
     .INCHANNEL_PARALLELISM(INCHANNEL_PARALLELISM),  
     .OUTCHANNEL_PARALLELISM(OUTCHANNEL_PARALLELISM)
    )
    pw(
        clk,
        pointwise_en,
        window_done,
        output_size,
        input_channel,
        output_channel,
        layer,
        point_infeature,
        point_inweight,
        outfeature,
        outh,
        outw,
        point_input_channel_sel,
        point_output_channel_sel,
        point_input_channel_sel_delay3,
        point_output_channel_sel_delay3,        
        point11_channel_done,
        point11_done,
        next_en,
        point_doing,
        point_done
    );
endmodule
