`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/02 15:30:40
// Design Name: 
// Module Name: control_unit
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


module control_unit(
    input clk,
    input init_buffer_done,
    input depth_done,
    input point_done,
    input POOL_done,
    input fc1_done,
    input fc2_done,
    input flatten_done,
    (*max_fanout=10*)output reg[3:0] layer = 0,
    output reg DSU_en,
    output reg depth_en,
    output reg point_en,
    output reg init_buffer,
    output reg fc1,
    output reg fc2,
    output reg flatten_en,
   (*max_fanout=10*) output reg[7:0] input_size,
   (*max_fanout=10*) output reg[7:0] output_size,
   (*max_fanout=10*) output reg[7:0] input_channel,
   (*max_fanout=10*) output reg[7:0] output_channel,
    output reg[3:0] feature_count=0   
    );
   always@(posedge clk)begin
        if(fc2_done)
            feature_count<=feature_count+1;
    end
    reg[3:0] next_layer=0;
    
    always@(posedge clk)begin
        layer<=next_layer;
    end
    always@(*)begin
        case(layer)
            0:next_layer = init_buffer_done?1:0;
            1:next_layer = depth_done?2:1;         
            2:next_layer = point_done?3:2;
            3:next_layer = POOL_done?4:3;
            
            4:next_layer = init_buffer_done?5:4;
            5:next_layer = depth_done?6:5;
            6:next_layer = point_done?7:6;
            7:next_layer = POOL_done?8:7;
            
            8:next_layer = init_buffer_done?9:8;
            9:next_layer = depth_done?10:9;
            10:next_layer = point_done?11:10;
            11:next_layer = POOL_done?12:11;
            
            12:next_layer = flatten_done?13:12;
            
            13:next_layer = fc1_done?14:13;
            
            14:next_layer = fc2_done?15:14;
            
            default:next_layer = 0;
        endcase
    end
    always@(*)begin
        case(layer)
        4'd0:begin//initbuffer
            input_size = 32;
            output_size = 32;
            input_channel = 3;
            output_channel = 32;
            DSU_en = 1;
            init_buffer = 1;
            depth_en = 1;
            point_en = 1;
            fc1=0;
            fc2=0;
            flatten_en = 0;
        end
        4'd1:begin//first layer
            input_size = 32;
            output_size = 32;
            input_channel = 3;
            output_channel = 32;
            DSU_en = 1;
            init_buffer = 0;
            depth_en = 1;
            point_en = 1;
            fc1=0;
            fc2=0    ;     
            flatten_en = 0;   
        end
        4'd2:begin
            input_size = 32;
            output_size = 32;
            input_channel = 3;
            output_channel = 32;
            DSU_en = 1;
            init_buffer = 0;
            depth_en = 0;
            point_en = 1;      
            fc1=0;
            fc2=0       ;  
            flatten_en = 0;         
        end
        4'd3:begin
            input_size = 32;
            output_size = 32;
            input_channel = 3;
            output_channel = 32;
            DSU_en = 1;
            init_buffer = 0;
            depth_en = 0;
            point_en = 0;
            fc1=0;
            fc2=0       ;   
            flatten_en = 0;  
        end
        4'd4:begin
            input_size = 16;
            output_size = 16;
            input_channel = 32;
            output_channel = 32;
            init_buffer = 1;
            DSU_en = 1;
            depth_en = 1;
            point_en = 1;
            fc1=0;
            fc2=0      ;    
            flatten_en = 0;  
        end
        4'd5:begin//
            input_size = 16;
            output_size = 16;
            input_channel = 32;
            output_channel = 32;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 1;
            point_en = 1;      
            fc1=0;
            fc2=0       ;    
            flatten_en = 0;       
        end
        4'd6:begin
             input_size = 16;
            output_size = 16;
            input_channel = 32;
            output_channel = 32;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 0;
            point_en = 1; 
            fc1=0;
            fc2=0         ;   
            flatten_en = 0;
        end
        4'd7:begin
             input_size = 16;
            output_size = 16;
            input_channel = 32;
            output_channel = 32;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 0;
            point_en = 0;     
            fc1=0;
            fc2=0     ;       
            flatten_en = 0;     
        end
        4'd8:begin//1000
            input_size = 8;
            output_size = 8;
            input_channel = 32;
            output_channel = 64;
            init_buffer = 1;
            DSU_en = 1;
            depth_en = 1;
            point_en = 1;
            fc1=0;
            fc2=0        ;   
            flatten_en = 0; 
            
        end
        4'd9:begin//1001
            input_size = 8;
            output_size = 8;
            input_channel = 32;
            output_channel = 64;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 1;
            point_en = 1;    
            fc1=0;
            fc2=0        ;   
            flatten_en = 0;         
        end
        4'd10:begin//1010
             input_size = 8;
            output_size = 8;
            input_channel = 32;
            output_channel = 64;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 0;
            point_en = 1; 
            fc1=0;
            fc2=0      ;    
            flatten_en = 0;  
        end
        4'd11:begin//1011
             input_size = 8;
            output_size = 8;
            input_channel = 32;
            output_channel = 64;
            init_buffer = 0;
            DSU_en = 1;
            depth_en = 0;
            point_en = 0;    
            fc1=0;
            fc2=0;            
            flatten_en = 0;      
        end     
        4'd12:begin
            input_size = 0;
            output_size = 0;
            input_channel = 0;
            output_channel = 0;
            init_buffer = 0;
            DSU_en = 0;
            depth_en = 0;
            point_en = 0;    
            fc1=0;
            fc2=0;           
            flatten_en = 1;    
        end   
        4'd13:begin
            input_size = 0;
            output_size = 0;
            input_channel = 0;
            output_channel = 0;
            init_buffer = 0;
            DSU_en = 0;
            depth_en = 0;
            point_en = 0;    
            fc1=1;
            fc2=0;         
            flatten_en = 0;      
        end           
        4'd14:begin
            input_size = 0;
            output_size = 0;
            input_channel = 0;
            output_channel = 0;
            init_buffer = 0;
            DSU_en = 0;
            depth_en = 0;
            point_en = 0; 
            fc1=0;
            fc2=1;          
            flatten_en = 0;
        end
        default:begin
            input_size = 0;
            output_size = 0;
            input_channel = 0;
            output_channel = 0;
            init_buffer = 0;
            DSU_en = 0;
            depth_en = 0;
            point_en = 0; 
            fc1=0;
            fc2=0;
            flatten_en = 0;        
        end
    endcase
    end
endmodule
