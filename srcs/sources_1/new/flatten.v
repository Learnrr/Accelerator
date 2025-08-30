`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/16 11:50:07
// Design Name: 
// Module Name: flatten
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


module flatten #(parameter DATA_WIDTH=16)(
    input clk,
    input clk2,
    input[3:0] layer,
    input en,
    input fc1_en,    
    input[DATA_WIDTH*8-1:0] pool_outdata,
    input[6:0] pool_addr,
    input[4:0] fcin_addr,
    output[DATA_WIDTH*32-1:0] fcin_data,
    output flatten_done
    );
    reg start=0;
    reg[5:0] start_point=0;
    reg read_done=0;
    reg[9:0] addr = 0;
    wire[DATA_WIDTH-1:0] data;    
    always@(posedge clk)begin
        if(en)start<=1;
        if(read_done)start<=0;
    end
    assign flatten_done = start_point==63&&addr==10'h3ff;
    wire mem1_ena = layer[3]&&layer[2]&&!en;
    blk_mem_gen_1 mem1(
        .addra(pool_addr),
        .clka(clk),
        .dina(pool_outdata),
        .ena(mem1_ena),
        .wea(mem1_ena),
        .addrb(addr),
        .clkb(clk),
        .doutb(data),
        .enb(en)
    );

    always@(posedge clk)begin
        if(start_point==63&&addr==960+start_point)begin
            read_done<=1;
        end
        if(layer==0)
            read_done<=0;        
    end
     
    always@(posedge clk)begin
        if(en&&!read_done)begin
            if(addr<1024)begin
                if(addr==960+start_point)begin
                    start_point<=start_point+1;
                    addr<=start_point+1;
                end
                else 
                    addr<=addr+64;
            end
        end
        else if(layer==0)begin
            addr<=0;
            start_point<=0;
        end        
    end
    
    reg[9:0] addr_w=0;
    always@(posedge clk)begin
        if(start&&!read_done)begin
            addr_w<=addr_w+1;
        end
        else if(layer==0)begin
            addr_w<=0;
        end        
    end
    
    blk_mem_gen_2 mem2(
        .addra(addr_w),
        .clka(clk),
        .dina(data),
        .ena(!read_done),
        .wea(!read_done),
        .addrb(fcin_addr),
        .clkb(clk2),
        .doutb(fcin_data),
        .enb(fc1_en)
    );
    
endmodule
