`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Flatten Unit
// this flatten unit is fixed to the network. feature map 4*4*64 -> 1024, but can be adjusted by adding some parameters which is not done yet  
// the flatten unit typically uses 2 dual port brams to reduce the dimention of output feature maps. it usually follows the last conv layer with or without pool.
//For conv layer with pooling, it writes data from pooling result to one of the brams. For that without pooling, it writes data from conv layer outputs. 
//the organization in bram1 is channel major and needs to become feature major in bram2. 
//////////////////////////////////////////////////////////////////////////////////
module flatten #(parameter DATA_WIDTH = 16, parameter POOL_PARALLELISM = 8)(
    input                                           clk,
    input[3:0]                                      layer,
    //enable flatten, working when en==1
    input                                           en,
    //full connect layer1 enable, used in this module to enable read mem2
    input                                           fc1_en,
    //pooling result
    input[DATA_WIDTH*POOL_PARALLELISM-1:0]          pool_outdata,
    //address to write first bram
    input[6:0]                                      pool_addr,
    //address to read second bram
    input[4:0]                                      fcin_addr,
    //data read from 2nd bram for fc layer
    output[DATA_WIDTH*32-1:0]                       fcin_data,
    //when the 2nd bram reads all of the data from 1st bram.
    output                                          flatten_done
    );
    
    //channel is to be processed 
    reg[5:0]                        start_point=0;
    //write to 2nd bram is done
    reg                             read_done=0;
    //address to read from bram1
    reg[9:0]                        addr = 0;
    //data read from 1st bram == write to 2st bram
    wire[DATA_WIDTH-1:0]            data;   
    //flatten process is running
    reg                             start=0;     
    always@(posedge clk)begin
        if(en)                  start<=1;
        if(read_done)           start<=0;
    end
    assign flatten_done = start_point==63&&addr==10'h3ff;

    blk_mem_gen_1 mem1(
        .addra(pool_addr),
        .clka(clk),
        .dina(pool_outdata),
        .ena(layer>=8&&layer<=11&&!en),
        .wea(layer>=8&&layer<=11&&!en),
        .addrb(addr),
        .clkb(clk),
        .doutb(data),
        .enb(en)
    );
    //read done
    always@(posedge clk)begin
        if(start_point==63&&addr==960+start_point)begin
            read_done<=1;
        end
        if(layer==0)
            read_done<=0;
    end
    //when flatten: 4*4*64->1024, the addr and start point work like this:
    //start_point:00, addr: 000,040,080,0c0,100,140...3c0
    //start_point:01, addr: 001,041,081,0c1...........3c1
    //start_point:02, addr: 002,042,082,0c2...........3c2
    //...
    //start_point:3f, addr: 03f,07f,0bf...............3ff -> flatten_done
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
    //address to write to bram2, from 0 to 3ff sequentially
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
        .clkb(clk),
        .doutb(fcin_data),
        .enb(fc1_en)
    );
    
endmodule