`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Control Unit 
// control unit works as a finite state machine, diff process in diff conv layers or fc layers is a state.
//////////////////////////////////////////////////////////////////////////////////
module control_unit(
//input port
    input                           clk,
    //some done signals for state transfer
    input                           init_buffer_done,
    input                           depth_done,
    input                           point_done,
    input                           POOL_done,
    input                           fc1_done,
    input                           fc2_done,
    input                           flatten_done,
//output port      
    output reg[3:0]                 layer = 0,
    //some enable signals
    output reg                      DSU_en,
    output reg                      depth_en,
    output reg                      point_en,
    //init 3 rows of layer window is a state
    output reg                      init_buffer,
    output reg                      fc1,
    output reg                      fc2,
    output reg                      flatten_en,
    //basic parameters in diff conv/fc layers
    output reg[7:0]                 input_size,
    output reg[7:0]                 output_size,
    output reg[7:0]                 input_channel,
    output reg[7:0]                 output_channel,
    //how many feature maps are processed
    output reg[3:0]                 feature_count=0
    );
       
    always@(posedge clk)begin
        if(fc2_done)   feature_count<=feature_count+1;
    end
    reg[3:0]                        next_layer=0;
    
    always@(posedge clk)begin
        layer<=next_layer;
    end
    always@(*)begin
        case(layer)//the layer here is state
        //conv layer1
            0:next_layer = init_buffer_done?1:0;
            1:next_layer = depth_done?2:1;         
            2:next_layer = point_done?3:2;
            3:next_layer = POOL_done?4:3;
        //conv layer2
            4:next_layer = init_buffer_done?5:4;
            5:next_layer = depth_done?6:5;
            6:next_layer = point_done?7:6;
            7:next_layer = POOL_done?8:7;
        //conv layer3
            8:next_layer = init_buffer_done?9:8;
            9:next_layer = depth_done?10:9;
            10:next_layer = point_done?11:10;
            11:next_layer = POOL_done?12:11;
        //flatten
            12:next_layer = flatten_done?13:12;
         //full connected layer1   
            13:next_layer = fc1_done?14:13;
          //full connected layer2  
            14:next_layer = fc2_done?15:14;
          //return to beginning 
            default:next_layer = 0;
        endcase
    end
    always@(*)begin
        if(layer==0)begin//initbuffer
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
        else if(layer==1)begin//first layer
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
        else if(layer==2)begin
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
        else if(layer==3)begin
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
        else if(layer==4)begin
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
        else if(layer==5)begin//
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
        else if(layer==6)begin
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
        else if(layer==7)begin
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
        else if(layer==8)begin
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
        else if(layer==9)begin//
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
        else if(layer==10)begin
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
        else if(layer==11)begin
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
        else if(layer == 12)begin
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
        else if(layer == 13)begin
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
        else if(layer==14)begin
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
        else begin
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
    end
endmodule
