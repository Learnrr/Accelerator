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
    output reg done_delay = 0
    );
    (*ram_style = "block"*)reg[DATA_WIDTH*2-1:0] bias[63:0];
    (* max_fanout = 5 *)reg[DATA_WIDTH*2-1:0] result[63:0];
    integer i;    
    initial begin
         $readmemb("../../../../../weights_8bit/fc1_bias.txt",bias);
        
        for(i=0;i<64;i=i+1)begin
            result[i]=0;
        end
        
    end

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
    reg[7:0] batch_delay1;
    reg[7:0] node_delay1;
    reg[7:0] batch_delay2;
    reg[7:0] node_delay2;
    reg[7:0] batch_delay3;
    reg[7:0] node_delay3;
    reg[7:0] batch_delay4;
    reg[7:0] node_delay4;
    reg[7:0] batch_delay5;
    reg[7:0] node_delay5;
    reg[7:0] batch_delay6;
    reg[7:0] node_delay6; 
    
    reg                             done=0;
    reg[7:0]                        delay_node1 = 0;
    reg[7:0]                        delay_batch1 = 0;
    reg[7:0]                        delay_node2 = 0;
    reg[7:0]                        delay_batch2 = 0;
    always@(posedge clk)begin
        delay_node1<=node_delay6;
        delay_batch1<=batch_delay6;
    end
              
    always@(posedge clk)begin
        if(node==0&&batch==0&&delay_node2==8'h3f)
            done<=1;
    end
    //assert done_delay
    always@(posedge clk)begin
        if (delay_node1 == 8'h3f && delay_batch1 == 31)
            done_delay<=1;
        else done_delay<=0;
    end 
        
    wire[DATA_WIDTH*2-1:0] temp_result[31:0];
    reg[DATA_WIDTH*2-1:0] temp_result2[15:0];
    reg[DATA_WIDTH*2-1:0] temp_result3[7:0];
    reg[DATA_WIDTH*2-1:0]temp_result4[3:0];
    reg[DATA_WIDTH*2-1:0] temp_result5[1:0];
    reg[DATA_WIDTH*2-1:0] temp_result6;
    
    genvar k;
    generate
        for(k=0;k<32;k=k+1)begin
            multiply_unit #(DATA_WIDTH)mul(clk,data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate
        //delay addr 1
    always@(posedge clk)begin
        batch_delay1 <= batch;
        node_delay1 <= node;
    end
    always@(posedge clk)begin
        for(i=0;i<16;i=i+1)begin
           temp_result2[i] <= en?temp_result[i]+temp_result[i+16]:0;
        end
    end
    always@(posedge clk)begin
        batch_delay2 <= batch_delay1;
        node_delay2 <= node_delay1;
    end        
    always@(posedge clk)begin
        for(i=0;i<8;i=i+1)begin
            temp_result3[i] <= en?temp_result2[i]+temp_result2[i+8]:0;
        end
    end
    //delay addr 3
    always@(posedge clk)begin
        batch_delay3 <= batch_delay2;
        node_delay3 <= node_delay2;
    end       
    always@(posedge clk)begin
        for(i=0;i<4;i=i+1)begin
            temp_result4[i] <= en?temp_result3[i]+temp_result3[i+4]:0;
        end
    end
    //delay addr 4
    always@(posedge clk)begin
        batch_delay4 <= batch_delay3;
        node_delay4 <= node_delay3;
    end     
    always@(posedge clk)begin  
        for(i=0;i<2;i=i+1)begin
            temp_result5[i] <= en?temp_result4[i]+temp_result4[i+2]:0;
        end
    end
    //delay addr 5
    always@(posedge clk)begin
        batch_delay5 <= batch_delay4;
        node_delay5 <= node_delay4;
    end       
    always@(posedge clk)begin
        temp_result6 <= en?temp_result5[0]+temp_result5[1]:0; 
    end
    //delay addr 6
    always@(posedge clk)begin
        batch_delay6 <= batch_delay5;
        node_delay6 <= node_delay5;
    end   

    
    always@(posedge clk)begin
    //one batch
    if(en)begin
        result[delay_node2] <= result[delay_node2]+temp_result6;
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
    output reg done_delay=0
    );

    reg[DATA_WIDTH*2-1:0] bias[9:0];
    (* max_fanout = 5 *)reg[DATA_WIDTH*2-1:0] result[9:0];    
    integer i;
    initial begin
        $readmemb("../../../../../weights_8bit/fc2_bias.txt",bias);
       
       for(i=0;i<10;i=i+1)begin
            result[i]=0;
       end
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
    //to address in the future, when pipeline is used
    //the pipeline level determines the cycles need to be delayed
    reg[7:0]                                node_delay1;
    reg[7:0]                                node_delay2;
    reg[7:0]                                node_delay3;
    reg[7:0]                                node_delay4;
    reg[7:0]                                node_delay5;
    reg[7:0]                                node_delay6;   
    reg[7:0]                                node_delay7;
    
    reg[3:0]                                delay_node=0;
    always@(posedge clk)begin
        delay_node<=node_delay7;
    end
    reg                                     done=0;
        //fc2 done
    always@(posedge clk)begin
        if(delay_node==8)                   done_delay<=1;
        if(done_delay)                      done_delay<=0;
    end
        
    wire[DATA_WIDTH*2-1:0] temp_result[63:0];
    reg[DATA_WIDTH*2-1:0] temp_result2[31:0];
    reg[DATA_WIDTH*2-1:0] temp_result3[15:0];
    reg[DATA_WIDTH*2-1:0] temp_result4[7:0];
    reg[DATA_WIDTH*2-1:0]temp_result5[3:0];
    reg[DATA_WIDTH*2-1:0] temp_result6[1:0];
    reg[DATA_WIDTH*2-1:0] temp_result7;
    genvar k;
    generate
        for(k=0;k<64;k=k+1)begin
           multiply_unit #(DATA_WIDTH)mul(clk,data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate
    //delay addr 1st
    always@(posedge clk)begin
        node_delay1 <= node;
    end        
    always@(posedge clk)begin
        for(i=0;i<32;i=i+1)begin
           temp_result2[i] <= en?temp_result[i]+temp_result[i+32]:0;
        end
    end
    //delay addr 2nd
    always@(posedge clk)begin
        node_delay2 <= node_delay1;
    end        
    always@(posedge clk)begin
        for(i=0;i<16;i=i+1)begin
            temp_result3[i] <= en?temp_result2[i]+temp_result2[i+16]:0;
        end
    end
    always@(posedge clk)begin
        node_delay3 <= node_delay2;
    end      
    always@(posedge clk)begin
        for(i=0;i<8;i=i+1)begin
            temp_result4[i] <= en?temp_result3[i]+temp_result3[i+8]:0;
        end
    end
    always@(posedge clk)begin
        node_delay4 <= node_delay3;
    end      
    always@(posedge clk)begin
        for(i=0;i<4;i=i+1)begin
            temp_result5[i] <= en?temp_result4[i]+temp_result4[i+4]:0;
        end
    end
    always@(posedge clk)begin
        node_delay5 <= node_delay4;
    end      
    always@(posedge clk)begin
        for(i=0;i<2;i=i+1)begin
            temp_result6[i] <= en?temp_result5[i]+temp_result5[i+2]:0;
        end
    end
    always@(posedge clk)begin
        node_delay6 <= node_delay5;
    end      
    always@(posedge clk)begin    
        temp_result7 <= en?temp_result6[0]+temp_result6[1]:0;
    end
    always@(posedge clk)begin
        node_delay7 <= node_delay6;
    end       
    
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
