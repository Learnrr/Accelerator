`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Full connect
// the full connect module uses node-batch method. it divides the input node into several batches. e.g. 1024 into 32 batches with each has 32 input nodes
// it traverses all the output nodes one by one. when it meets a node, it start to traverse batches. 
// it at a time calculates one batch, which is to multiply all the corresponding inputs and weights in this batch. then the next batch
// the result of a batch is accumulated to the node result, and after all the batches of a node, it starts at next output node.
//////////////////////////////////////////////////////////////////////////////////
//in this network 1024->64
module full_connect1 #(parameter DATA_WIDTH = 16)(
    input                                   clk,
    input[3:0]                              layer,
    input                                   en,
    input[32*DATA_WIDTH-1:0]                data,
    input[32*DATA_WIDTH-1:0]                weight,
    output reg[4:0]                         batch = 0,
    output reg[5:0]                         node=0,
    output [64*DATA_WIDTH-1:0]              out,
    output done
    );
    //delay_node is one cycle later than node, node is used as address in weight rom;
    //rom read needs one cycle, so when write results, node is one cycle former.
    reg[5:0]                        delay_node = 0;
    always@(posedge clk)begin
        delay_node<=node;
    end
    //bias rom
    (*ram_style = "block"*)
    reg[DATA_WIDTH*2-1:0]           bias[63:0]; 
    initial begin
         $readmemb("D:/weights/fc1_bias.txt",bias);
    end
    //result and intialization
    reg[DATA_WIDTH*2-1:0]           result[63:0];    
    integer                         i;       
    initial begin  
        for(i=0;i<64;i=i+1)begin
            result[i]='d0;
        end    
    end
    //fc1 done when node and batch meet end and start a new cycle, i.e. from the last to first 0
    //at the same time, delay_node meets end because it's one cycle later.
    assign done = node==0&&batch==0&&delay_node==6'h3f;
    //node and batch inc logic
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
    
    //use adder tree to accumulate multiply results. it needs a long combinational logic path, and gives rise to timing closure issues.
    //so it needs more improvement
    wire[DATA_WIDTH*2-1:0]                      temp_result[31:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result2[15:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result3[7:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result4[3:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result5[1:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result6;
    
    genvar k;
    generate
        for(k=0;k<32;k=k+1)begin
            multiply_unit_fc #(.DATA_WIDTH(DATA_WIDTH))mul(data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate
    generate
        for(k=0;k<16;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder1(1'b0,temp_result[k],temp_result[k+16],temp_result2[k]);
        end
    endgenerate
    generate
        for(k=0;k<8;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder2(1'b0,temp_result2[k],temp_result2[k+8],temp_result3[k]);
        end
    endgenerate
    generate
        for(k=0;k<4;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder3(1'b0,temp_result3[k],temp_result3[k+4],temp_result4[k]);
        end
    endgenerate
    generate   
        for(k=0;k<2;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder4(1'b0,temp_result4[k],temp_result4[k+2],temp_result5[k]);
        end
    endgenerate
    adder #(.DATA_WIDTH(DATA_WIDTH))adder5(1'b0,temp_result5[0],temp_result5[1],temp_result6);
    
    
    always@(posedge clk)begin
        //one batch
        if(en) begin
             result[delay_node] <= result[delay_node][DATA_WIDTH*2-1]==temp_result6[DATA_WIDTH*2-1]?{temp_result6[DATA_WIDTH*2-1],temp_result6[DATA_WIDTH*2-2:0]+result[delay_node][DATA_WIDTH*2-2:0]}
                :(temp_result6[DATA_WIDTH*2-2:0]>result[delay_node][DATA_WIDTH*2-2:0]?{temp_result6[DATA_WIDTH*2-1],temp_result6[DATA_WIDTH*2-2:0]-result[delay_node][DATA_WIDTH*2-2:0]}
                :{result[delay_node][DATA_WIDTH*2-1],result[delay_node][DATA_WIDTH*2-2:0]-temp_result6[DATA_WIDTH*2-2:0]});
        end
        else if(layer==0)begin
             for(i=0;i<64;i=i+1)begin
                 result[i]<='d0;
             end
        end
    end
    
    //result with fc bias
    wire[DATA_WIDTH*2-1:0]                      result_bias[63:0];
    
    //add bias
    genvar j;
    generate
        for(j=0;j<64;j=j+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder(1'b0,result[j],bias[j],result_bias[j]);
        end
    endgenerate
    //results with bias and quantization
    wire[DATA_WIDTH*2-1:0]                      result_quan[63:0];
    generate
        for(j=0;j<64;j=j+1)begin
            assign result_quan[j] ={result_bias[j][DATA_WIDTH*2-1], result_bias[j][DATA_WIDTH*2-2:0]>>17};
        end
    endgenerate
    //truncation
    generate
        for(j=0;j<64;j=j+1)begin
            assign out[DATA_WIDTH*j+DATA_WIDTH-1-:DATA_WIDTH] = {result_quan[j][DATA_WIDTH*2-1],result_quan[j][DATA_WIDTH-2:0]};
        end
    endgenerate
endmodule

// in this network 64->10
//fc2 layer is almost the same as fc1. but has no batch division because its 64 input nodes are calculated at one time. 
module full_connect2 #(parameter DATA_WIDTH = 16)(
    input                                   clk,
    input[3:0]                              layer,
    input                                   en,
    input[64*DATA_WIDTH-1:0]                data,
    input[64*DATA_WIDTH-1:0]                weight,

    output reg[3:0]                         node=0,
    output [10*DATA_WIDTH-1:0]              out,
    output reg                              done=0
    );
    reg[3:0]                                delay_node=0;
    always@(posedge clk)begin
        delay_node<=node;
    end
    //bias rom
    reg[DATA_WIDTH*2-1:0]                       bias[9:0];
    initial begin
        $readmemb("D:/weights/fc2_bias.txt",bias);
    end    
    //final result
    reg[DATA_WIDTH*2-1:0]                       result[9:0];    
    integer                         i;    
    initial begin
       for(i=0;i<10;i=i+1)begin
            result[i]='d0;
       end
    end
    //fc2 done
    always@(posedge clk)begin
        if(delay_node==9)       done<=1;
        if(done)                done<=0;
    end
    //node inc logic
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
    //accumulate
    wire[DATA_WIDTH*2-1:0]                      temp_result[63:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result2[31:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result3[15:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result4[7:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result5[3:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result6[1:0];
    wire[DATA_WIDTH*2-1:0]                      temp_result7;
    
    genvar  k;
    generate
        for(k=0;k<64;k=k+1)begin
            multiply_unit_fc #(.DATA_WIDTH(DATA_WIDTH))mul(data[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],weight[DATA_WIDTH*k+DATA_WIDTH-1-:DATA_WIDTH],temp_result[k]);
        end
    endgenerate
    generate
        for(k=0;k<32;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder1(1'b0,temp_result[k],temp_result[k+32],temp_result2[k]);
        end
    endgenerate
    generate
        for(k=0;k<16;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder2(1'b0,temp_result2[k],temp_result2[k+16],temp_result3[k]);
        end
    endgenerate
    generate
        for(k=0;k<8;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder3(1'b0,temp_result3[k],temp_result3[k+8],temp_result4[k]);
        end
    endgenerate
    generate
        for(k=0;k<4;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder4(1'b0,temp_result4[k],temp_result4[k+4],temp_result5[k]);
        end
    endgenerate
    generate   
        for(k=0;k<2;k=k+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder5(1'b0,temp_result5[k],temp_result5[k+2],temp_result6[k]);
        end
    endgenerate
    adder #(.DATA_WIDTH(DATA_WIDTH))adder6(1'b0,temp_result6[0],temp_result6[1],temp_result7);
    
    always@(posedge clk)begin
    //one batch
        if(en&&!done)begin
            if(node||delay_node)
               result[delay_node] <= result[delay_node][DATA_WIDTH*2-1]==temp_result7[DATA_WIDTH*2-1]?{temp_result7[DATA_WIDTH*2-1],temp_result7[DATA_WIDTH*2-2:0]+result[delay_node][DATA_WIDTH*2-2:0]}
            :(temp_result7[DATA_WIDTH*2-2:0]>result[delay_node][DATA_WIDTH*2-2:0]?{temp_result7[DATA_WIDTH*2-1],temp_result7[DATA_WIDTH*2-2:0]-result[delay_node][DATA_WIDTH*2-2:0]}
            :{result[delay_node][DATA_WIDTH*2-1],result[delay_node][DATA_WIDTH*2-2:0]-temp_result7[DATA_WIDTH*2-2:0]});
        end
        else if(layer==0)begin
             for(i=0;i<10;i=i+1)begin
                result[i]<='d0;
            end
        end
    end
    //add bias
    wire[DATA_WIDTH*2-1:0]                      result_bias[9:0];
    genvar j;
    generate
        for(j=0;j<10;j=j+1)begin
            adder #(.DATA_WIDTH(DATA_WIDTH))adder(1'b0,result[j],bias[j],result_bias[j]);
        end
    endgenerate
    //quantization
    wire[DATA_WIDTH*2-1:0]                      result_quan[9:0];
    generate
        for(j=0;j<10;j=j+1)begin
            assign result_quan[j] ={result_bias[j][DATA_WIDTH*2-1], result_bias[j][DATA_WIDTH*2-2:0]>>15};
        end
    endgenerate
    //truncate
    generate
        for(j=0;j<10;j=j+1)begin
            assign out[DATA_WIDTH*j+DATA_WIDTH-1-:DATA_WIDTH] = {result_quan[j][DATA_WIDTH*2-1],result_quan[j][DATA_WIDTH-2:0]};
        end
    endgenerate
endmodule
