`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: P2P buffer
// 
//////////////////////////////////////////////////////////////////////////////////


module intermediate_buffer2 #(parameter DATA_WIDTH = 16, parameter OUTCHANNEL_PARALLELISM = 8, parameter POOL_PARALLELISM = 8)(
    input                                               clk,
    //pooling out column position
    input[7:0]                                          col,
    
    input[3:0]                                          layer,
    //to enable pointwise outputs write
    input                                               point_doing,
    //to which channel the point output data belong 
    input[7:0]                                          point_output_channel_sel_delay3,
    input[7:0]                                          point_input_channel_sel_delay3,
    //pooling read address
    input[7:0]                                          pool_channel_sel,
    
    input                                               point11_done,
    //point result
    input[DATA_WIDTH*OUTCHANNEL_PARALLELISM-1:0]        point_output,
 //output port
    //to pooling unit
    output [DATA_WIDTH*POOL_PARALLELISM*2-1:0]          pool_input,
    //1*2 pooling inputs ready, signal to start pooling
    output reg                                          done=0
    );
    //point11_done_delay is to help some signals in this module rise or drop at the proper time 
    reg                                                 point11_done_delay=0;
    always@(posedge clk)begin
        point11_done_delay<=point11_done;
    end
    
    //write enable
    reg                                                 write=0;
    always@(posedge clk)begin
        if(point_doing)begin
            write<=1;
        end
        else if(point11_done_delay)begin
            write<=0;
        end
    end
    
    //for addr, because bram read need one more cycle, it need to be delayed 
    reg[7:0]                                            poc_sel=0;
    always@(posedge clk)begin//delay one cycle
        poc_sel<=point_output_channel_sel_delay3;
    end
    reg[7:0]                                            pic_sel=0;
    always@(posedge clk)begin
        pic_sel<=point_input_channel_sel_delay3;
    end
    
    //P2P buffer has 2 identical buffer lane for 1*2 pooling, when 1 is full, the other begins to fill
    //write_done is to signal one is full.
    reg                                                 write_done=0;
    always@(posedge clk)begin
        if(write&&point11_done)begin
            write_done<=1;
        end
        else if(write_done)begin
            write_done<=0;
        end
    end
    //to select which buffer lane is to fill
    reg                                                 buffer_sel = 0;
    always@(posedge clk)begin
        if(write_done)begin
            buffer_sel<= ~buffer_sel;
        end
    end
    
    //done signals that pool inputs are ready
    always@(posedge clk)begin
        done<=0;
        if(point11_done&&buffer_sel==1)begin
            done<=1;
        end
    end
    
    //pointwise unit at a time calculate OCP outputchannels and ICP inputchannels
    //need to accumulate outputs across inputchannels to these OCP output channels.
    //e.g. 1: 0-8 outchannel: 0-8 inchannel----> write to buffer at the pos of 0-8 outchannel
    //     2: 0-8 outchannel: 8-16 inchannel----> add to buffer at the pos of 0-8 outchannel
    //     3: 8-16 outchannel: 0-8 inchannel----> write to buffer at the pos of 8-16 outchannel
    //     4: 8-16 outchannel: 8-16 inchannel----> add to buffer at the pos 8-16 outchannel
    integer                                             i;
    //to store intermediate result of OCP output channels
    reg[DATA_WIDTH*OUTCHANNEL_PARALLELISM-1:0]          buffer_indata = 0;
    always@(posedge clk)begin
        if(write)begin
            // pic_sel>0 means it's te followed inputchannels of the output channels, need to accumulate to buffer_indata
            if(pic_sel>0)begin
                for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
                    buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH] <= buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1]==point_output[DATA_WIDTH*i+DATA_WIDTH-1]?{buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1],buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]+point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]}:(buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]>point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]?{buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1],buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]-point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]}:{point_output[DATA_WIDTH*i+DATA_WIDTH-1],point_output[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]-buffer_indata[DATA_WIDTH*i+DATA_WIDTH-2-:DATA_WIDTH-1]});
                end
            end
            //otherwise, it's the first ICP inputchannels of output channels, need to write to buffer_indata
            else begin
                for(i=0;i<OUTCHANNEL_PARALLELISM;i=i+1)begin
                    buffer_indata[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH] <= point_output[DATA_WIDTH*i+DATA_WIDTH-1-:DATA_WIDTH];
                end
            end
        end
    end
    
    //signals to make 'ena' change at the proper time
    wire[7:0]                                           pic_write = layer<4?0:8'h18; 
    reg                                                 buffer_sel_delay=0;
    always@(posedge clk)begin
        buffer_sel_delay <= buffer_sel;
    end    
    wire                                                ena_A;
    assign ena_A = write&&buffer_sel_delay==0&&layer<4||write&&buffer_sel==0&&pic_sel==pic_write&&layer>4;
    reg                                                 ena_A_delay=0;
    always@(posedge clk)begin
        ena_A_delay<=ena_A;
    end
    //data read from bufferA
    wire[DATA_WIDTH*POOL_PARALLELISM-1:0]               bufferA_outdata;
    //write address
    reg[2:0]                                            bufferA_inaddr=0;
    always@(posedge clk)begin
         bufferA_inaddr <= poc_sel/OUTCHANNEL_PARALLELISM;
    end
    P2P_buffer bufferA(
        .addra(bufferA_inaddr),//write address is to use pointwise channel
        .clka(clk),
        .dina(buffer_indata),
        .ena(layer<4?ena_A:ena_A_delay),
        .wea(layer<4?ena_A:ena_A_delay),
        .addrb(pool_channel_sel/POOL_PARALLELISM),//read address is to use pool channel
        .clkb(clk),
        .doutb(bufferA_outdata),
        .enb(1'b1)
    );
    
    
   //the same as bufferA
    reg                                                 ena_B_delay=0;  
    wire                                                ena_B;
    assign ena_B = write&&buffer_sel_delay==1&&layer<4||write&&buffer_sel==1&&pic_sel==pic_write&&layer>4;
    always@(posedge clk)begin
        ena_B_delay<=ena_B;
    end
    wire[DATA_WIDTH*POOL_PARALLELISM-1:0]               bufferB_outdata;
    wire[7:0]                                           col_end;
    assign col_end = layer<4?15:(layer<8?7:3);
    
    P2P_buffer bufferB(
        .addra(bufferA_inaddr),
        .clka(clk),
        .dina(buffer_indata),
        .ena(layer<4?(col==col_end&&ena_B==0&&ena_B_delay==1?1:ena_B):ena_B_delay),
        .wea(layer<4?(col==col_end&&ena_B==0&&ena_B_delay==1?1:ena_B):ena_B_delay),
        .addrb(pool_channel_sel/POOL_PARALLELISM),
        .clkb(clk),
        .doutb(bufferB_outdata),
        .enb(1'b1)
    );
    
    //organize buffer out data and transmit to pool inputs
    genvar ii;
    generate for(ii=0;ii<POOL_PARALLELISM*2;ii=ii+2)begin
        assign pool_input[DATA_WIDTH*ii+DATA_WIDTH-1-:DATA_WIDTH] = bufferA_outdata[DATA_WIDTH*(ii/2)+DATA_WIDTH-1-:DATA_WIDTH];
    end endgenerate
    
    generate for(ii=1;ii<POOL_PARALLELISM*2;ii=ii+2)begin
        assign pool_input[DATA_WIDTH*ii+DATA_WIDTH-1-:DATA_WIDTH] = bufferB_outdata[DATA_WIDTH*(ii/2)+DATA_WIDTH-1-:DATA_WIDTH];
    end endgenerate
endmodule
