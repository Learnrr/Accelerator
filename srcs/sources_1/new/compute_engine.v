`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Compute_engine which is PE
// each PE is a MAC tree and processes one channel of 3*3 data. the leaves multiply and get through a adder tree
//in this module, some intermediate results need to be stored in register and passed to followed parts.
//if the pipeline stage is 4, there needs to be 3 registers to separate 4 stages.
//////////////////////////////////////////////////////////////////////////////////


//3*3 compute engine
module compute_engine #(parameter DATA_WIDTH = 16)(
    input                               clk,
    //these signals are to make clk_count work properly.
    input                               en,
    input                               channel_done,     
    input                               started,
    //channel selected are to be processed. used to record which channels are the results belong to after 3 cycles.
    //like RISC-V CPU intermediate registers to pass some signals to following stages
    input[7:0]                          channel_sel,    
    //inputs
    input[DATA_WIDTH*9-1:0]             data,
    input[DATA_WIDTH*9-1:0]             weight,
    
    output[DATA_WIDTH*2-1:0]            result,
    //channels to which the just processed data belong
    output reg[7:0]                     channel_sel_delay3=0,    
    //3 cycle of computation is done
    output                              done
    );
    //clock counts, pipeline stage is 4 so when equals to 3 ,done is asserted
    reg[1:0]                            clk_count = 0;
    //inc logic of clock count
    always@(posedge clk)begin
        if(en)                          clk_count <= 0;
        else if(done)                   clk_count <= 0;
        else if(started&&channel_done)  clk_count <= clk_count == 3 ? 0 : clk_count + 1;        
    end
    //when equals to 3 ,done is asserted
    assign done = clk_count == 3;
    
    //mul result of the leaves in MAC tree
    wire[DATA_WIDTH*2-1:0]              intermediate_result[8:0]; 
    //2 dimentional, easy index
    reg[DATA_WIDTH-1:0]                 temp_data[8:0]; 
    reg[DATA_WIDTH-1:0]                 temp_weight[8:0];
    //channel selected delayed one cycle. if pipeline stage is 4, need to be delayed 3 times
    reg[7:0]                            channel_sel_delay=0;
    
    //pipeline stage1: data organization
    //data organization
    integer                             i;
    always@(posedge clk)begin
        for(i=0;i<9;i=i+1)begin
            temp_data[i] <= data[DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH];
            temp_weight[i] <= weight[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH];
        end
        channel_sel_delay <= channel_sel;
    end     
    //pipeline stage2: multiplication
    //compute in leaves
    generate 
    genvar j;
        for(j=0;j<9;j = j+1)
            begin: compute
                multiply_unit#(.DATA_WIDTH(DATA_WIDTH)) multiply_unit(clk,temp_data[j],temp_weight[j],intermediate_result[j]);
            end
    endgenerate
    //for there is a cycle in the mul_unit, need to be delayed once again
    reg[7:0]                            channel_sel_delay2=0;
    always@(posedge clk)begin
        channel_sel_delay2<=channel_sel_delay;
    end
    //pipeline stage3; addition
   //adder tree
   //not fully parameterized, different parallelism needs diff tree structure. need more improvement here
   wire[DATA_WIDTH*2-1:0]               out1,out2,out3,out4,out5,out6,out7;
   adder #(.DATA_WIDTH(DATA_WIDTH))adder1(1'b0,intermediate_result[0],intermediate_result[1],out1);
   adder #(.DATA_WIDTH(DATA_WIDTH))adder2(1'b0,intermediate_result[2],intermediate_result[3],out2);
   adder #(.DATA_WIDTH(DATA_WIDTH))adder3(1'b0,intermediate_result[4],intermediate_result[5],out3);
   adder #(.DATA_WIDTH(DATA_WIDTH))adder4(1'b0,intermediate_result[6],intermediate_result[7],out4);
   
   adder #(.DATA_WIDTH(DATA_WIDTH))adder5(1'b0,out1,out2,out5);
   adder #(.DATA_WIDTH(DATA_WIDTH))adder6(1'b0,out3,out4,out6);
   
   //channel_sel delayed once again in another pipeline stage
   reg[DATA_WIDTH*2-1:0]                out5_delay,out6_delay,inter8_delay;
   always@(posedge clk)begin
        out5_delay<=out5;
        out6_delay<=out6;
        channel_sel_delay3<=channel_sel_delay2;
        inter8_delay<=intermediate_result[8];
   end
   
   //the last stage contains several addition and post process in depthwise module
   adder #(.DATA_WIDTH(DATA_WIDTH))adder7(1'b0,out5_delay,out6_delay,out7);
   
   adder #(.DATA_WIDTH(DATA_WIDTH))adder8(1'b0,out7,inter8_delay,result);

endmodule

