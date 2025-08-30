`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description:  pointwise computing engine -- PE
// each PE calculates 8 inputchannels of 1 outputchannel at a time
//not fully parameterized, adder tree is fixed
//////////////////////////////////////////////////////////////////////////////////

module compute_engine_p #(parameter DATA_WIDTH = 16, parameter INCHANNEL_PARALLELISM = 8, parameter OUTCHANNEL_PARALLELISM = 8)(
    input                               clk,
    //channel selected are to be processed. used to record which channels are the results belong to after 3 cycles.
    //like RISC-V CPU intermediate registers to pass some signals to following stages
    input[7:0]                          input_channel_sel,
    input[7:0]                          output_channel_sel,   
    //inputs and outputs
    input[DATA_WIDTH*8-1:0]             data,
    input[DATA_WIDTH*8-1:0]             weight,
    output[DATA_WIDTH*2-1:0]            result,
    //delayed channel_select
    output reg[7:0]                     input_channel_sel_delay3=0,
    output reg[7:0]                     output_channel_sel_delay3=0
    );
    //pipeline stage1 : data organization
    //store 1 dim data from input port to 2 dimentional data
    reg[DATA_WIDTH-1:0]                   temp_data[INCHANNEL_PARALLELISM-1:0]; 
    reg[DATA_WIDTH-1:0]                   temp_weight[INCHANNEL_PARALLELISM-1:0];
    //mul results
    wire[DATA_WIDTH*2-1:0]                intermediate_result[INCHANNEL_PARALLELISM-1:0];    
    //channel_select is first delayed
    reg[7:0]                               input_channel_sel_delay1=0;
    reg[7:0]                               output_channel_sel_delay1=0;
 
    integer i;
    always@(posedge clk)begin
        for(i=0;i<INCHANNEL_PARALLELISM;i=i+1)begin
            temp_data[i]<=data[DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH];
            temp_weight[i] <= weight[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH];
        end
        input_channel_sel_delay1<=input_channel_sel;
        output_channel_sel_delay1<=output_channel_sel;    
    end     
    //pipeline stage2: multiplication
     //computation of 8(ICP) input channels
    generate 
    genvar j;
        for(j=0;j<INCHANNEL_PARALLELISM;j = j+1)
            begin: compute
                multiply_unit#(.DATA_WIDTH(DATA_WIDTH)) multiply_unit(clk,temp_data[j],temp_weight[j],intermediate_result[j]);
            end
    endgenerate
    //2nd channel_sel delay becuase there is a delay in mul_unit
    reg[7:0]                            input_channel_sel_delay2=0;
    reg[7:0]                            output_channel_sel_delay2=0;    
    always@(posedge clk)begin
        input_channel_sel_delay2<=input_channel_sel_delay1;
        output_channel_sel_delay2<=output_channel_sel_delay1;
    end
    
    //pipeline stage3: addition
    //adder tree
    //not fully parameterized, adder tree is fixed
    wire[DATA_WIDTH*2-1:0]              out1,out2,out3,out4,out5,out6;
    adder #(.DATA_WIDTH(DATA_WIDTH))adder1(1'b0,intermediate_result[0],intermediate_result[1],out1);
    adder #(.DATA_WIDTH(DATA_WIDTH))adder2(1'b0,intermediate_result[2],intermediate_result[3],out2);
    adder #(.DATA_WIDTH(DATA_WIDTH))adder3(1'b0,intermediate_result[4],intermediate_result[5],out3);
    adder #(.DATA_WIDTH(DATA_WIDTH))adder4(1'b0,intermediate_result[6],intermediate_result[7],out4);  
      
    adder #(.DATA_WIDTH(DATA_WIDTH))adder5(1'b0,out1,out2,out5);
    adder #(.DATA_WIDTH(DATA_WIDTH))adder6(1'b0,out3,out4,out6);
    
    //pipeline stage4: some remaining addtions and post process such as quantization
    //3rd channel_select delay
    reg[DATA_WIDTH*2-1:0]               out5_delay,out6_delay;
    always@(posedge clk)begin
         out5_delay<=out5;
         out6_delay<=out6;
         input_channel_sel_delay3<=input_channel_sel_delay2;
         output_channel_sel_delay3<=output_channel_sel_delay2;         
    end
    adder #(.DATA_WIDTH(DATA_WIDTH))adder7(1'b0,out5_delay,out6_delay,result);

endmodule
