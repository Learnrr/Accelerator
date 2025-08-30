`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/15 09:34:36
// Design Name: 
// Module Name: full_connect
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


module full_connect1 #(parameter DATA_WIDTH=8)(
    input clk,
    input[3:0]layer,    
    input en,
    input[32*DATA_WIDTH-1:0] data,//high low
    input[32*DATA_WIDTH-1:0] weight,//high low
    output reg[4:0] batch = 0,
    output reg[5:0] node=0,
    output [64*DATA_WIDTH-1:0] out,
    output done
    );
    reg[5:0] delay_node = 0;
    always@(posedge clk)begin
            delay_node<=node;
    end 

    (*ram_style = "block"*)reg[DATA_WIDTH*2-1:0] bias[63:0];
    (* max_fanout = 5 *)reg[DATA_WIDTH*2-1:0] result[63:0];
    integer i;    
    initial begin
         $readmemb("D:/weights/fc1_bias.txt",bias);
        
        for(i=0;i<64;i=i+1)begin
            result[i]=0;
        end
        
    end
    assign done = node==0&&batch==0&&delay_node==6'h3f;

    always@(posedge clk)begin
        if(en)begin
            if(batch<32)begin
                if(batch==31)begin
                    if(node<64)begin
                        if(node==63)begin
                            node<=0;
                        end
                        else begin
                        node<=node+1;
                        end
                    end
                    
                    batch<=0;
                end
                else begin
                    batch<=batch+1;
                end
            end
        end
         else if(layer==0)begin
            node<=0;
            batch<=0;
        end        
    end
    wire[DATA_WIDTH*2-1:0] temp_result[31:0];
    wire[DATA_WIDTH*2-1:0] temp_result2[15:0];
    wire[DATA_WIDTH*2-1:0] temp_result3[7:0];
    wire[DATA_WIDTH*2-1:0]temp_result4[3:0];
    wire[DATA_WIDTH*2-1:0] temp_result5[1:0];
    wire[DATA_WIDTH*2-1:0] temp_result6;
    
    genvar k;
    generate
        for(k=0;k<32;k=k+1)begin
            multiply_unit_fc #(DATA_WIDTH)mul(data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate

    generate
        for(k=0;k<16;k=k+1)begin
           assign temp_result2[k] = temp_result[k]+temp_result[k+16];
        end
    endgenerate
    generate
        for(k=0;k<8;k=k+1)begin
            assign temp_result3[k] = temp_result2[k]+temp_result2[k+8];
        end
    endgenerate
    generate
        for(k=0;k<4;k=k+1)begin
             assign temp_result4[k] = temp_result3[k]+temp_result3[k+4];
        end
    endgenerate
    generate   
        for(k=0;k<2;k=k+1)begin
          assign temp_result5[k] = temp_result4[k]+temp_result4[k+2];
        end
    endgenerate

        assign temp_result6 = temp_result5[0]+temp_result5[1];

    
    always@(posedge clk)begin
    //one batch
    if(en)begin
        result[delay_node] <= result[delay_node]+temp_result6;
     end
     else if(layer==0)begin
             for(i=0;i<64;i=i+1)begin
                result[i]<=0;
            end
     end        
    end
    
    wire[DATA_WIDTH*2-1:0] result_bias[63:0];
    
    //output 
    genvar j;
    generate
        for(j=0;j<64;j=j+1)begin
            assign result_bias[j] = result[j]+bias[j];
        end
    endgenerate
    wire[DATA_WIDTH*2-1:0] result_quan[63:0];
    generate
        for(j=0;j<64;j=j+1)begin
            assign result_quan[j] ={result_bias[j][DATA_WIDTH*2-1], result_bias[j][DATA_WIDTH*2-2:0]>>17};
        end
    endgenerate
    generate
        for(j=0;j<64;j=j+1)begin
            assign out[DATA_WIDTH*j+DATA_WIDTH-1-:DATA_WIDTH] = {result_quan[j][DATA_WIDTH*2-1],result_quan[j][DATA_WIDTH-2:0]};
        end
    endgenerate
endmodule

module full_connect2 #(parameter DATA_WIDTH=8)(
    input clk,
    input[3:0] layer,    
    input en,
    input[64*DATA_WIDTH-1:0] data,
    input[64*DATA_WIDTH-1:0] weight,

    output reg[3:0] node=0,
    output [10*DATA_WIDTH-1:0] out,
    output reg done=0
    );
    reg[3:0] delay_node=0;
    always@(posedge clk)begin
        delay_node<=node;
    end
    reg[DATA_WIDTH*2-1:0] bias[9:0];
    (* max_fanout = 5 *)reg[DATA_WIDTH*2-1:0] result[9:0];    
    integer i;
    initial begin
        $readmemb("D:/weights/fc2_bias.txt",bias);
       
       for(i=0;i<10;i=i+1)begin
            result[i]=0;
       end
    end
    always@(posedge clk)begin
        if(delay_node==9)
            done<=1;
        if(done) done<=0;
    end
 
    always@(posedge clk)begin
        if(en)begin
                if(node<10)begin
                    if(node==9)begin
                        node<=0;
                    end
                    else begin
                        node<=node+1;
                    end
                end       
         end
         else if(layer==0)begin
            node<=0;
         end            
    end
    wire[DATA_WIDTH*2-1:0] temp_result[63:0];
    wire[DATA_WIDTH*2-1:0] temp_result2[31:0];
    wire[DATA_WIDTH*2-1:0] temp_result3[15:0];
    wire[DATA_WIDTH*2-1:0] temp_result4[7:0];
    wire[DATA_WIDTH*2-1:0]temp_result5[3:0];
    wire[DATA_WIDTH*2-1:0] temp_result6[1:0];
    wire[DATA_WIDTH*2-1:0] temp_result7;
    genvar k;
    generate
        for(k=0;k<64;k=k+1)begin
           multiply_unit_fc #(DATA_WIDTH)mul(data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate
    generate
        for(k=0;k<32;k=k+1)begin
            assign temp_result2[k] = temp_result[k]+temp_result[k+32];
        end
    endgenerate
    generate
        for(k=0;k<16;k=k+1)begin
            assign temp_result3[k] = temp_result2[k]+temp_result2[k+16];
        end
    endgenerate
    generate
        for(k=0;k<8;k=k+1)begin
            assign temp_result4[k] = temp_result3[k]+temp_result3[k+8];
        end
    endgenerate
    generate
        for(k=0;k<4;k=k+1)begin
            assign temp_result5[k] = temp_result4[k]+temp_result4[k+4];
        end
    endgenerate
    generate   
        for(k=0;k<2;k=k+1)begin
            assign temp_result6[k] = temp_result5[k]+temp_result5[k+2];
        end
    endgenerate
    assign temp_result7 = temp_result6[0]+temp_result6[1];
    always@(posedge clk)begin
    //one batch
        if(en&&!done)begin
            if(node||delay_node)
                result[delay_node] <= result[delay_node]+temp_result7;
        end
        else if(layer==0)begin
             for(i=0;i<10;i=i+1)begin
                result[i]<=0;
            end
        end        
    end
    wire[DATA_WIDTH*2-1:0] result_bias[9:0];
    //output 
    genvar j;
    generate
        for(j=0;j<10;j=j+1)begin
            assign result_bias[j] = result[j]+bias[j];
        end
    endgenerate
    wire[DATA_WIDTH*2-1:0] result_quan[9:0];
    generate
        for(j=0;j<10;j=j+1)begin
            assign result_quan[j] ={result_bias[j][DATA_WIDTH*2-1], result_bias[j][DATA_WIDTH*2-2:0]>>15};
        end
    endgenerate
    generate
        for(j=0;j<10;j=j+1)begin
            assign out[DATA_WIDTH*j+DATA_WIDTH-1-:DATA_WIDTH] = {result_quan[j][DATA_WIDTH*2-1],result_quan[j][DATA_WIDTH-2:0]};
        end
    endgenerate
endmodule
