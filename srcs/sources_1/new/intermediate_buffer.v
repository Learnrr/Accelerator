`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/01 15:06:18
// Design Name: 
// Module Name: intermediate_buffer
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


module intermediate_buffer #(parameter DATA_WIDTH=8)(
    input clk,
    input[3:0] layer,
    input depth_channel_done,    
    input[7:0] depth_channel_sel_delay3,
    input[7:0] point_channel_sel,
    input point11_done,
    input depth33_done,
    input[DATA_WIDTH*4-1:0] depth_output,
    output [DATA_WIDTH*8-1:0] point_input,
    output reg done=0
    );
        
    //because point and depth calculate one cycle later than channel sel
    reg depth33_done_delay=0;
    reg point11_done_delay=0;

    always@(posedge clk)begin
        depth33_done_delay<=depth33_done;
        point11_done_delay<=point11_done;
    end
     reg write_end_sg=0;
    reg read,write=0;
    always@(posedge clk)begin
        if(depth33_done_delay)begin
            write_end_sg<=1;
        end
        if(depth_channel_sel_delay3==0)begin
             write_end_sg<=0;
        end
    end

    always@(*)begin
        if(depth33_done_delay&&layer<4)begin
            write=1;
        end
        else if(!write_end_sg&&depth_channel_sel_delay3>0&&layer>=4)begin
            write=1;
        end
        else write=0;
    end  
    //read from and write to which buffer -- pingpong buffer 
    reg read_sel=0,write_sel=0;
    always@(posedge clk)begin
        if(layer<4)begin
            write_sel<=0;
            read_sel<=0;
        end
        else begin
            if(depth33_done_delay)begin
                write_sel<=~write_sel;
            end
            if(point11_done_delay)begin
                read_sel<=~read_sel;
            end
        end
    end
    reg[7:0] dep_sel=0;
    always@(posedge clk)begin
        dep_sel<=depth_channel_sel_delay3;
    end
    
    //depth done-> ready for next stage
    always@(posedge clk)begin
        done<=0;
        if(depth33_done)begin
            done<=1;
        end
    end
    
    wire[3:0] buffer_inaddr;
    wire[2:0] buffer_outaddr;
    assign buffer_inaddr = (write_sel<<3)+(dep_sel>>2);
    assign buffer_outaddr = (read_sel<<2)+(point_channel_sel>>3);
    
    reg[DATA_WIDTH*8-1:0] point_input_register;
     wire[DATA_WIDTH*8-1:0] point_input_temp;
    always@(posedge clk)begin
        point_input_register<=point_input_temp;
    end
    assign point_input = layer<4?point_input_register:point_input_temp;
    //pingpong buffer   holds depthwise out feature
    D2P_buffer D2P_buffer(
        .addra(buffer_inaddr),
        .clka(clk),
        .dina(depth_output),
        .ena(write),
        .wea(write),
        .addrb(buffer_outaddr),
        .clkb(clk),
        .doutb(point_input_temp),
        .enb(1'b1)
    );

endmodule
