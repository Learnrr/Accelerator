`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Pooling engines and Pooling buffer 
// 

//////////////////////////////////////////////////////////////////////////////////
module pool#(parameter DATA_WIDTH = 16, parameter POOL_PARALLELISM = 8)(
    input                                                   clk,
    //enable to start a new 1*2 pooling
    input                                                   en,
    //params from cu
    input[7:0]                                              input_size,
    input[7:0]                                              channel,
    //1*2 inputs
    input[DATA_WIDTH*POOL_PARALLELISM*2-1:0]               infeature,
    //outputs
    output reg[DATA_WIDTH*POOL_PARALLELISM-1:0]            outfeature,
    //pool out position
    output reg[7:0]                                         outh,
    output reg[7:0]                                         outw,
    //col for write into pool buffer
    output reg[7:0]                                         inw,
    //which of the channels are doing
    output reg[7:0]                                         channel_sel,
    //channel sel meets the end
    output                                                  channel_done,
    //for time sequence issues
    output reg                                              done_delay2=0
    );
    //row for write into pool buffer
    reg[7:0]                        inh;
    
    //if started
    reg                             started;
    always@(posedge clk)begin
        if(en)                      started <= 1;
        if(channel_done)            started<=0;
    end
    //pool_doing is one cycle after 'started'. it's for time sequence issues
    reg                             pool_doing;
    always@(posedge clk)begin
        pool_doing <= started;
    end
    //*2 pool channel select is done
    assign channel_done =(channel_sel>=channel-POOL_PARALLELISM||channel<=POOL_PARALLELISM);
    
    //whole feature pool is done, but some writes to feature memory outside are not. -- done_delay
    assign done = outh==input_size/2 -1 &&outw==input_size/2 -1 &&channel_done;
    //delay one cycle to ensure layer changed one cylce later
    //if not set, layer changed quickly when pool done, and pool outfeature is written to the wrong place of feature memory in TOP module
    //so it's for time sequence issues
    reg                             done_delay=0;
    always@(posedge clk)begin
        done_delay<=done;
    end
    always@(posedge clk)begin
        done_delay2<=done_delay;
    end
    
   initial begin
        outh = 0;
        outw = 0;
        inh=0;
        inw=0;
        channel_sel=0;
        started = 0;
   end
    
    //unpack inputs
    genvar                          i,k;
    wire[DATA_WIDTH*2-1:0]          inputs[POOL_PARALLELISM-1:0];
    wire[DATA_WIDTH-1:0]            result[POOL_PARALLELISM-1:0];
    generate
        for(i=0;i<POOL_PARALLELISM;i=i+1)begin
            assign inputs[i] = infeature[DATA_WIDTH*2*i+DATA_WIDTH*2-1 -: DATA_WIDTH*2];
        end
    endgenerate
    //for 1*2 pooling and the PCP is 8 here
    generate for(i=0;i<POOL_PARALLELISM;i=i+1)begin
        max_pool 
        #(
        .DATA_WIDTH(DATA_WIDTH)
        )
        pool(
        inputs[i][DATA_WIDTH-1:0],
        inputs[i][DATA_WIDTH*2-1:DATA_WIDTH],
        result[i]
        );
    end
    endgenerate
    
    //pos to 2 layer pool buffer, inw ranges from 0-output_size-1, inh ranges from 0-1, 0 represents odd row, 1 represents even row
    always@(posedge clk)begin
        if(channel_done)begin
            if(inw<input_size/2)begin              
                if(inw == input_size/2-1)begin
                    if(inh<2)begin
                        if(inh == 1)begin
                            inh <= 0;
                        end
                        else inh <= inh+1;
                    end
                    else inh<=0;
                    inw<=0;
                end
                else inw <= inw + 1;               
             end
             else inw<=0;
        end
        else begin
            inh<=inh;
            inw<=inw;
        end
    end
    //pool channel selection
    always@(posedge clk)begin
        if(en)                                       channel_sel<=0;
        else if(channel_done)                        channel_sel<=0;
        else if(started&&channel_sel<channel-8)      channel_sel <= channel_sel + 8;
        else                                         channel_sel <= 0;
    end

    // write to pool buffer
    
    //inh_delay is for time sequence issues
    reg[7:0]                        inh_delay=0;
    always@(posedge clk)begin
        inh_delay<=inh;
    end
    
    wire[DATA_WIDTH*POOL_PARALLELISM-1:0]          buffer_outdata;
    wire[6:0]                                       buf_outaddr;
    assign buf_outaddr=8*inw+channel_sel/POOL_PARALLELISM;
    reg[6:0]                        buf_inaddr;
    always@(posedge clk)begin
        buf_inaddr<=buf_outaddr;
    end
    // buffer input is composed of PCP channels of 1*2 pooling result
    reg[DATA_WIDTH*POOL_PARALLELISM-1:0]           buffer_indata;
    integer                         j;
    always@(*)begin
        if(pool_doing)begin
            for(j=0;j<POOL_PARALLELISM;j=j+1)begin
                buffer_indata[DATA_WIDTH*j+DATA_WIDTH-1 -: DATA_WIDTH] <= inh_delay==0?result[j]:0;
            end
        end
    end
    
    pool_buffer pool_buffer(
        .addra(buf_inaddr),
        .clka(clk),
        .dina(buffer_indata),
        .ena(inh_delay==0&&pool_doing),
        .wea(inh_delay==0&&pool_doing),
        .addrb(buf_outaddr),
        .clkb(clk),
        .doutb(buffer_outdata),
        .enb(started&&inh==1)
    );
    //2*1 pooling result
    wire[DATA_WIDTH-1:0]             result_h[POOL_PARALLELISM-1:0];
    
    //2*1 pooling engines PCP is 8
    generate for(i=0;i<POOL_PARALLELISM;i=i+1)begin
        max_pool 
        #(
        .DATA_WIDTH(DATA_WIDTH)
        )
        pool_even(
        buffer_outdata[DATA_WIDTH*i+DATA_WIDTH-1 -: DATA_WIDTH],
        result[i],
        result_h[i]
        );
    end
    endgenerate
    
    // output: if it's the odd row, output is 0, if even row, output is 2*1 pooling result
    always@(posedge clk)begin
        for(j=0;j<POOL_PARALLELISM;j=j+1)begin
            outfeature[DATA_WIDTH*j+DATA_WIDTH-1 -: DATA_WIDTH] <= inh_delay==0?0:result_h[j];
        end
    end
    
    // output position out h w
    always@(posedge clk)begin
        if(inh==1)begin
            if(channel_done)begin
                if(outw<input_size/2)begin
                    if(outw==input_size/2-1)begin
                        outw<=0;
                        if(outh<input_size/2)begin
                            if(outh==input_size/2-1)begin
                                outh<=0;
                            end
                            else outh<=outh+1;
                        end
                        else outh<=0;
                    end
                    else outw<=outw+1;
                end
                else outw<=0;
            end
        end
        else begin
            outw<=outw;
            outh<=outh;
        end
    end
    
endmodule
