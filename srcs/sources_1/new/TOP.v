`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/02 15:06:16
// Design Name: 
// Module Name: TOP
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


//...
module TOP #(parameter DATA_WIDTH = 8)(
    input clk,
    input clk2,
    output reg[9:0] out=0
    );
    wire[3:0] layer;//from cu
    //dsu
    wire[7:0] input_size,output_size,input_channel,output_channel;
    wire DSU_en;

    wire[7:0] inh,inw,outh,outw,depth_channel_sel,point_output_channel_sel_delay3,point_input_channel_sel_delay3;
    wire[DATA_WIDTH*8-1:0] DSU_outblock;
    wire[DATA_WIDTH*3*3-1:0] DSU_inblock1,DSU_inblock2,DSU_inblock3,DSU_inblock4;
    wire DSU_done;
    //pool
    wire[DATA_WIDTH*8*2-1:0] pool_infeature;
    wire[DATA_WIDTH*8-1:0] pool_outfeature;
    wire[7:0] pool_outh,pool_outw,pool_channel_sel;
    wire[11:0] pool_outaddr;
    wire init_buffer;
    wire[12:0] addr;
    wire[DATA_WIDTH*4-1:0] data;
    wire init_buffer_done;
    
    wire[12:0] first_feature_addr = 13'h000;
    wire[12:0] second_feature_addr = 13'h400;
    // diff addr by layer
    
    //pool out data to bram addr--delay one cycle
    reg[7:0] pool_outh_delay=0,pool_outw_delay=0,pool_channel_sel_delay=0;
    reg[7:0] pool_outh_delay2=0,pool_outw_delay2=0,pool_channel_sel_delay2=0;
    always@(posedge clk)begin
        pool_outh_delay<=pool_outh;
        pool_outw_delay<=pool_outw;
        pool_channel_sel_delay<=pool_channel_sel;
    end
    always@(posedge clk)begin
        pool_outh_delay2<=pool_outh_delay;
        pool_outw_delay2<=pool_outw_delay;
        pool_channel_sel_delay2<=pool_channel_sel_delay;
    end
    wire[7:0] pool_outaddr_outh_shift;
    assign pool_outaddr_outh_shift=layer<4?6:(layer<8?5:5);
    wire[7:0] pool_outaddr_outw_shift;
    assign pool_outaddr_outw_shift=layer<4?2:(layer<8?2:3);
    assign pool_outaddr = ((layer<4 || layer>7)?second_feature_addr[11:0]:first_feature_addr[11:0])+(pool_outh_delay2<<pool_outaddr_outh_shift) + (pool_outw_delay2<<pool_outaddr_outw_shift)+ (pool_channel_sel_delay2>>3);
    //layer base addr  
    wire[12:0] base_addr;
    assign base_addr = (layer<4 || layer>7)?first_feature_addr*2:second_feature_addr*2;
     blk_mem_gen_0 bram0(
         .addra(pool_outaddr),
         .clka(clk),
         .dina(pool_outfeature),
         .ena(1'b1),
         .wea(1'b1),
         .addrb(addr),
         .clkb(clk),
         .doutb(data),
         .enb(1'b1) 
      );
    wire depth33_done;
    wire[DATA_WIDTH*4-1:0] towindowdata0,towindowdata1,towindowdata2;
    wire depth_layer_done;
    wire[7:0] depth_channel;
     input_buffer_block #(1,DATA_WIDTH)ibb(
        clk,
        init_buffer,
        depth_layer_done,
        layer,
        input_size,
        input_channel,
        inw,
        depth_channel,
        base_addr,
        depth33_done,
        data,
        init_buffer_done,
        addr,
       towindowdata0,
       towindowdata1,
       towindowdata2
    );
    wire window_done,first_window_done;    wire point_output_channel_done;
        wire depthwise_en;    
    wire first_cycle;
    wire next_en;
    pixel_window #(1,DATA_WIDTH)pixel_window(
        clk,
        init_buffer,
        init_buffer_done,
        input_size,
        input_channel,
         depth_channel_sel,
        first_cycle,
        next_en,
        depthwise_en,        
        towindowdata0,
        towindowdata1,
        towindowdata2,
        inw,
        depth_channel,
        DSU_inblock1,
        DSU_inblock2,
        DSU_inblock3,
        DSU_inblock4,
        first_window_done,
        window_done   
    );
    wire point_doing;
    wire pool_done;    
    wire pool_channel_done;
    wire depth_en,point_en;
    wire depth_done,point_done;
    wire point11_done;
  DSU #(DATA_WIDTH)DSU(
        clk,
        DSU_en, 
        init_buffer,
        window_done,
        first_window_done,
        depth_en,
        point_en,
        layer,
        input_size,
        output_size,
        input_channel,
        output_channel,
        DSU_inblock1,
        DSU_inblock2,
        DSU_inblock3,
        DSU_inblock4,
        depth_channel_sel,
        first_cycle,
        next_en,
        depth33_done,
        point_input_channel_sel_delay3,
        point_output_channel_sel_delay3,
        depthwise_en,        
        DSU_outblock,
        point11_done,
        point_doing,
        depth_layer_done,
        depth_done,
        point_done
    );
    wire ibb2_done;
    wire pool_doing;
    wire[7:0] pool_inw;
   intermediate_buffer2 #(DATA_WIDTH)ibb2(
        clk,
        pool_inw,
        layer,
        pool_doing,
        point_doing,
        point_output_channel_sel_delay3,
        point_input_channel_sel_delay3,
        pool_channel_sel,
        point11_done,
        DSU_outblock,
        pool_infeature,
        ibb2_done
    );
  pool #(DATA_WIDTH)max_pool(
        clk,
        ibb2_done,
        output_size,
        output_channel,
        pool_infeature,
        pool_outfeature,
        pool_outh,
        pool_outw,
        pool_inw,
        pool_channel_sel,
        pool_doing,
        pool_channel_done,
        pool_done
    );
     wire[4:0] fc1_batch;
     wire[32*DATA_WIDTH-1:0] fc1_indata,fc1_indata_copy;
     wire flatten_en,flatten_done;
     wire[6:0] pool_addr;
     //used when outputsize=4 and outputchannel=64
     //assign pool_addr = (output_size/2)*(output_channel/8)*(pool_outh_delay2) + (pool_outw_delay2)*(output_channel/8)+ pool_channel_sel_delay2/8;
       assign pool_addr = (pool_outh_delay2<<4) + (pool_outw_delay2<<3)+ pool_channel_sel_delay2>>3;
    wire fc1_en,fc2_en,fc1_done,fc2_done;
    flatten #(DATA_WIDTH)flatten(
        clk,
        clk2,
        layer,
        flatten_en,
        fc1_en,        
        pool_outfeature,
        pool_addr,
        fc1_batch,
        fc1_indata,
        flatten_done     
     );
    

     wire[64*DATA_WIDTH-1:0] fc2_weight,fc2_indata;
     wire[32*DATA_WIDTH-1:0] fc1_weight,fc1_weight_copy;
     wire[5:0] fc1_node;
     wire[3:0] fc2_node;
     wire[64*DATA_WIDTH-1:0] fc1_out;
     wire[10:0] fc1_weight_addr;
     
     assign fc1_weight_addr = fc1_node*32+fc1_batch;
     blk_mem_gen_3 fc1_weight_rom(
        .addra(fc1_weight_addr),
        .clka(clk2),
        .douta(fc1_weight),
        .ena(fc1_en)
     );
     reg fc1_en_delay=0;
     always@(posedge clk)begin
        fc1_en_delay<=fc1_en;
     end
     assign fc1_indata_copy = fc1_en_delay?fc1_indata:0;
     assign fc1_weight_copy = fc1_en_delay?fc1_weight:0;     
     full_connect1 #(DATA_WIDTH)fc1(
           clk2,
           layer,           
           fc1_en,
           fc1_indata_copy,
           fc1_weight_copy,
           fc1_batch,
           fc1_node,
           fc1_out,
           fc1_done
      );  
      assign fc2_indata = fc1_out;
      
      blk_mem_gen_4 fc2_weight_rom(
        .addra(fc2_node),
        .clka(clk2),
        .douta(fc2_weight),
        .ena(fc2_en)
      );
      
      wire[10*DATA_WIDTH-1:0] fc2_out;
     full_connect2 #(DATA_WIDTH) fc2(
           clk2,
           layer,           
           fc2_en,
           fc2_indata,
           fc2_weight,
           fc2_node,
           fc2_out,
           fc2_done
      );
      
      control_unit cu(
        clk,
        init_buffer_done,
        depth_done,
        point_done,
        pool_done,
        fc1_done,
        fc2_done,
        flatten_done,
        layer,
        DSU_en,
        depth_en,
        point_en,     
        init_buffer,
        fc1_en,
        fc2_en,
        flatten_en,
        input_size,
        output_size,
        input_channel,
        output_channel,
        feature_count        
    );
    reg[1:0] fc2_done_count=0;
    always@(posedge clk)begin
        if(fc2_done)
            fc2_done_count<=fc2_done_count==3?3:fc2_done_count+1;
    end
    always@(posedge clk)begin
        if(fc2_done&&fc2_done_count<3)begin
         out[0] <= fc2_out[DATA_WIDTH*0+DATA_WIDTH-1];
         out[1] <= fc2_out[DATA_WIDTH*1+DATA_WIDTH-1];
         out[2] <= fc2_out[DATA_WIDTH*2+DATA_WIDTH-1];
         out[3] <= fc2_out[DATA_WIDTH*3+DATA_WIDTH-1];
         out[4] <= fc2_out[DATA_WIDTH*4+DATA_WIDTH-1];
         out[5] <= fc2_out[DATA_WIDTH*5+DATA_WIDTH-1];
         out[6] <= fc2_out[DATA_WIDTH*6+DATA_WIDTH-1];
         out[7] <= fc2_out[DATA_WIDTH*7+DATA_WIDTH-1];
         out[8] <= fc2_out[DATA_WIDTH*8+DATA_WIDTH-1];
         out[9] <= fc2_out[DATA_WIDTH*9+DATA_WIDTH-1];
        end
    end
    
endmodule
