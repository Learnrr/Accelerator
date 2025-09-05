`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/09 14:06:35
// Design Name: 
// Module Name: intermediate_buffer2
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


module intermediate_buffer2 #(parameter DATA_WIDTH=16)(
    input clk,
    input[7:0] col,
    input[3:0] layer,
    input pool_doing,
    input point_doing,
    input[7:0] point_output_channel_sel_delay3,//output channel
    input[7:0] point_input_channel_sel_delay3,
    input[7:0] pool_channel_sel,
    input point11_done,//output channel
    input[DATA_WIDTH*8-1:0] point_output,
    output [DATA_WIDTH*8*2-1:0] pool_input,
    output reg done=0
    );
    reg point11_done_delay=0;
    always@(posedge clk)begin
        point11_done_delay<=point11_done;
    end
    reg read,write=0;
    always@(posedge clk)begin
        if(point_doing)begin
            write<=1;
        end
        else if(point11_done_delay)begin
            write<=0;
        end
    end    
   reg[7:0] poc_sel=0;
    always@(posedge clk)begin//delay one cycle
        poc_sel<=point_output_channel_sel_delay3;
    end
    reg[7:0] pic_sel=0;
    always@(posedge clk)begin
        pic_sel<=point_input_channel_sel_delay3;
    end
    reg write_done=0;
    always@(posedge clk)begin
        if(write&&point11_done)begin
            write_done<=1;
        end
        else if(write_done)begin
            write_done<=0;
        end
    end
  //  reg[15:0] buffer[63:0][1:0];
    reg buffer_sel = 0;
    always@(posedge clk)begin
        if(write_done)begin
            buffer_sel<= ~buffer_sel;
        end
    end
    always@(posedge clk)begin
        done<=0;
        if(point11_done&&buffer_sel==1)begin
            done<=1;
        end
    end

    reg buffer_sel_delay=0;
    always@(posedge clk)begin
        buffer_sel_delay<=buffer_sel;
    end

    integer i;
    reg[DATA_WIDTH*8-1:0] buffer_indata = 0;
    always@(posedge clk)begin
        if(write)begin
            if(pic_sel>0)begin
                for(i=0;i<8;i=i+1)begin
                   // buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH] <= buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1]==point_output[DATA_WIDTH*i+DATA_WIDTH-1]?{buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1],buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2 -:DATA_WIDTH-1]+point_output[DATA_WIDTH*i+DATA_WIDTH-2 -:DATA_WIDTH-1]}:(buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]>point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]?{buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1],buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]-point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]}:{point_output[DATA_WIDTH*i+DATA_WIDTH-1],point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]-buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]});
                    buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH] <= buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH]+point_output[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH];
                end
            end
            else begin
                 for(i=0;i<8;i=i+1)begin
                    buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH] <= point_output[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH];
                end
            end
        end
    end
    
    wire[7:0] pic_write = layer<4?0:8'h18;
    reg[2:0] bufferA_inaddr=0;
    always@(posedge clk)begin
         bufferA_inaddr <= poc_sel/8;
    end
    
    wire ena_A = write&&buffer_sel_delay==0&&layer<4||write&&buffer_sel==0&&pic_sel==pic_write&&layer>4;
    reg ena_A_delay=0;
    always@(posedge clk)begin
        ena_A_delay<=ena_A;
    end
    wire[DATA_WIDTH*8-1:0] bufferA_outdata;
    P2P_buffer bufferA(
        .addra(bufferA_inaddr),
        .clka(clk),
        .dina(buffer_indata),
        .ena(layer<4?ena_A:ena_A_delay),
        .wea(layer<4?ena_A:ena_A_delay),
        .addrb(pool_channel_sel/8),
        .clkb(clk),
        .doutb(bufferA_outdata),
        .enb(1'b1)
    );
    
     reg[2:0] bufferB_inaddr=0;
     always@(posedge clk)begin
         bufferB_inaddr <= poc_sel/8;
     end
   
    wire ena_B = write&&buffer_sel_delay==1&&layer<4||
    write&&buffer_sel==1&&pic_sel==pic_write&&layer>4;
   
    reg ena_B_delay=0;
    always@(posedge clk)begin
        ena_B_delay<=ena_B;
    end
    wire[DATA_WIDTH*8-1:0] bufferB_outdata;
    wire[7:0] col_end = layer<4?15:(layer<8?7:3);
    P2P_buffer bufferB(
        .addra(bufferA_inaddr),
        .clka(clk),
        .dina(buffer_indata),
        .ena(layer<4?(col==col_end&&ena_B==0&&ena_B_delay==1?1:ena_B):ena_B_delay),
        .wea(layer<4?(col==col_end&&ena_B==0&&ena_B_delay==1?1:ena_B):ena_B_delay),
        .addrb(pool_channel_sel/8),
        .clkb(clk),
        .doutb(bufferB_outdata),
        .enb(1'b1)
    );
    genvar ii;
    generate for(ii=0;ii<16;ii=ii+2)begin
        assign pool_input[DATA_WIDTH*ii+DATA_WIDTH-1-:DATA_WIDTH] = bufferA_outdata[DATA_WIDTH*(ii/2)+DATA_WIDTH-1-:DATA_WIDTH];
    end endgenerate
    
    generate for(ii=1;ii<16;ii=ii+2)begin
        assign pool_input[DATA_WIDTH*ii+DATA_WIDTH-1-:DATA_WIDTH] = bufferB_outdata[DATA_WIDTH*(ii/2)+DATA_WIDTH-1-:DATA_WIDTH];
    end endgenerate
endmodule
