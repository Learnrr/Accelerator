`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: D2P buffer
// it functions as a ping pong buffer to avoid depthwise and pointwise data collisions
//////////////////////////////////////////////////////////////////////////////////


module intermediate_buffer #(parameter DATA_WIDTH = 16,parameter CHANNEL_PARALLELISM = 4, parameter INCHANNEL_PARALLELISM = 8)(
    input                                                   clk,
    input[3:0]                                              layer,
    input[7:0]                                              depth_channel_sel_delay3,
    input[7:0]                                              point_channel_sel,
    input                                                   point11_channel_done,
    input                                                   depth33_done,
    
    input[DATA_WIDTH*CHANNEL_PARALLELISM-1:0]               depth_output,
    output[DATA_WIDTH*INCHANNEL_PARALLELISM-1:0]            point_input,
    output reg                                              done=0
    );
    
    //to make 'write_end_sg' 'write_sel' and 'write' asserted at the proper time 
    reg                         depth33_done_delay=0;
    always@(posedge clk)begin
        depth33_done_delay<=depth33_done;
    end
    //write end signal
    reg                         write_end_sg=0;
    always@(posedge clk)begin
        if(depth33_done_delay)begin
            write_end_sg <= 1;
        end
        if(depth_channel_sel_delay3 == 0)begin
             write_end_sg <= 0;
        end
    end
    //when to enable write
    reg                         write=0;
    always@(*)begin
        if(depth33_done_delay && layer<4)begin
            write = 1;
        end
        else if(!write_end_sg && depth_channel_sel_delay3>0 && layer>=4)begin
            write = 1;
        end
        else write = 0;
    end
    
    //read from and write to which buffer -- pingpong buffer 
    reg                         read_sel=0,write_sel=0;
    always@(posedge clk)begin
        if(layer<4)begin
            write_sel <= 0;
            read_sel <= 0;
        end
        else begin
            if(depth33_done_delay)begin
                write_sel <= ~write_sel;
            end
            if(point11_channel_done)begin
                read_sel <= ~read_sel;
            end
        end
    end
    
    //delay depth_channel_sel_delay3 one cycle for buffer addr, for meet sequential issue 
    reg[7:0]                    dep_sel=0;
    always@(posedge clk)begin
        dep_sel <= depth_channel_sel_delay3;
    end
    
    //depth writing to intermediate buffer is done-> ready for next stage(point)
    always@(posedge clk)begin
        done <= 0;
        if(depth33_done)begin
            done <= 1;
        end
    end
    //addr for reading from or writing to D2P buffer
    wire[3:0]                                       buffer_inaddr;
    wire[2:0]                                       buffer_outaddr;
    //buffer addr: select buffer A or B by using base addr: write_sel*(32/CHANNEL_PARALLELISM), and plus offset dep_sel/CHANNEL_PARALLELISM
    assign buffer_inaddr = write_sel*(32/CHANNEL_PARALLELISM)       +      dep_sel/CHANNEL_PARALLELISM;
    assign buffer_outaddr = read_sel*(32/INCHANNEL_PARALLELISM)     +      point_channel_sel/INCHANNEL_PARALLELISM;
    
    //set for the proposed network conv layer 1.  it has 3 channels input so it's time sequence is diff from others, 
    //so use the 'point_input_register' to delay one cycle
    //it's derived from the functional simulation graph
    reg[DATA_WIDTH*INCHANNEL_PARALLELISM-1:0]       point_input_register;
    wire[DATA_WIDTH*INCHANNEL_PARALLELISM-1:0]      point_input_temp;
    always@(posedge clk)begin
        point_input_register <= point_input_temp;
    end
    assign point_input = layer<4?point_input_register:point_input_temp;
    // the D2P buffer size depends on the network structure
    //pingpong buffer  it holds depthwise outputs,which are pointwise inputs
    //    BUFA     BUFB
    // ------------------
    // \        \       \   unit size for reading:  4(DCP) data items, unit num: 32/4 = 8
    // ------------------   unit size for writing:  8(ICP) data items, unit num: 32/8 = 4
    // \        \       \
    // ------------------
    // \        \       \
    // ------------------
    // \        \       \
    // ------------------
    // \        \       \
    // ..................  
    // \        \       \
    // ------------------

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
