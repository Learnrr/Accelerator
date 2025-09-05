`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/28 09:46:06
// Design Name: 
// Module Name: DSU
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


module DSU #(parameter DATA_WIDTH=8)(
    input clk,
    input en,
    input init_buffer,
    input window_done,
    input init,
    input depth_en,
    input point_en,
    input[3:0] layer,
    input[7:0] input_size,
    input[7:0] output_size,
    input[7:0] input_channel,
    input[7:0] output_channel,
    input[DATA_WIDTH*3*3-1:0] depth_infeature1,
    input[DATA_WIDTH*3*3-1:0] depth_infeature2,
    input[DATA_WIDTH*3*3-1:0] depth_infeature3,
    input[DATA_WIDTH*3*3-1:0] depth_infeature4,
    output[7:0] depth_channel_sel,
    output first_cycle,
    output next_en,
    output depth33_done,
    output[7:0] point_input_channel_sel_delay3,
    output[7:0] point_output_channel_sel_delay3,
    output depthwise_en,       
    output[DATA_WIDTH*8-1:0]outfeature,
    output point11_done,
    output point_doing,
    output depth_layer_done,
    output depth_done,
    output point_done
    );
    
    wire pointwise_en;
    wire[DATA_WIDTH*3*3*4-1:0] depth_inweight;
    wire[DATA_WIDTH*4-1:0] depth_outfeature;
    
     wire[4:0] depth_base_addr;
    assign depth_base_addr = layer<4?5'd0:(layer<8?5'd1:(layer<12?5'd9:5'd0));
    
    wire[4:0] depth_weight_addr;
    assign depth_weight_addr = depth_base_addr+depth_channel_sel/4;
    depth_weight_rom depth_weight_rom(
        .addra(depth_weight_addr),
        .clka(clk),
        .douta(depth_inweight)
    );
    wire[7:0] depth_channel_sel_delay3;
    wire depth_doing;
    wire depth_channel_done;    
    depthwise #(DATA_WIDTH,3,4,1)dw(//32@32*32->32@32*32
        clk,
        depthwise_en,
        init_buffer,
        window_done,
        next_en,
        point_done,
        input_size,
        output_size,
        input_channel,
        layer,
        depth_infeature1,
        depth_infeature2,
        depth_infeature3,
        depth_infeature4,
        depth_inweight,
        depth_outfeature,
        depth_channel_sel,
        depth_channel_sel_delay3,
        depth_doing,
        first_cycle,
        depth_channel_done,        
        depth33_done,
        depth_layer_done,
        depth_done
    );
    wire[7:0] point_input_channel_sel,point_output_channel_sel;
    wire[DATA_WIDTH*8-1:0] point_infeature;
    wire[DATA_WIDTH*8*8-1:0] inweight;
    
   wire[7:0] point_base_addr;
   assign point_base_addr = layer<4?8'd0:(layer<8?8'd4:(layer<12?8'd20:8'd0));
    
    wire[7:0] point_weight_addr;
    assign point_weight_addr = point_base_addr+(point_output_channel_sel/8)*((input_channel<8?8:input_channel)/8)+point_input_channel_sel/8;//4*16+
    point_weight_rom point_weight_rom(
        .addra(point_weight_addr),
        .clka(clk),
        .douta(inweight),
        .ena(1'b1)
    );
    wire point11_channel_done;
    wire ib_done;
    intermediate_buffer #(DATA_WIDTH)ib(
        clk,
        layer,
        depth_channel_done,        
        depth_channel_sel_delay3,
        point_input_channel_sel,
        point11_channel_done,
        depth33_done,
        depth_outfeature,
        point_infeature,
        ib_done      
    );

    pointwise #(DATA_WIDTH)pw(//32@32*32->32@32*32
        clk,
        pointwise_en,
        window_done,
        output_size,
        input_channel,
        output_channel,
        layer,
        point_infeature,
        inweight,
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
     reg depth33_done_delay=0;
    always@(posedge clk)begin
        if(depth33_done)
            depth33_done_delay<=1;
        if(first_cycle)begin
            depth33_done_delay<=0;
        end
    end
    assign pointwise_en = point_en&&en&&ib_done;
    assign depthwise_en = depth_en&&en&&(init||window_done&&(layer<4&&depth33_done||layer>=4&&depth33_done_delay&&next_en));
endmodule
