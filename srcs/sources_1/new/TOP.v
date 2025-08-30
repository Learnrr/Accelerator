`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: the top module instantiate all the modules
// which can be seen at project hierarchy.
//parameters are used across the project but the adder tree in point and depth PE are not fully parameterized
//they need to be adjusted with the change of channel parallelism parameters .
// IPs also need some reconfiguration if change the parameters.
//DO NOT change the parameters unless improvement at the position above are done 
// some signals seem incomprehensible because they are set there due to time&sequence issues according to the functional simulation graph 
//////////////////////////////////////////////////////////////////////////////////

//...
module TOP #(
    parameter DATA_WIDTH = 16,
    parameter UPDATE_PARALLELISM = 4,
    parameter CHANNEL_PARALLELISM = 4, 
    parameter INCHANNEL_PARALLELISM = 8, 
    parameter OUTCHANNEL_PARALLELISM = 8, 
    parameter POOL_PARALLELISM = 8)(
    //systerm clock
    input clk,
    //10 classes
    output reg[9:0] out=0
    );
    //from control unit, basic parameters
    wire[3:0]                                           layer;
    wire[7:0]                                           input_size,output_size,input_channel,output_channel;
    
    //DSU
    // signal to enable dsu to work, from control unit
    wire                                                DSU_en;
    //output feature position,from dsu --- not used    
    wire[7:0]                                           outh,outw;
    //current depthwise channels in computation, if DCP is 4 and channel 0-4 in computation, depth_channel_sel = 0
    wire[7:0]                                           depth_channel_sel;
    // from dsu pointwise unit, channel address to write intermeidate buffer2. if data to write is input_ch 0-8 and output_ch 0-8, both are 0
    //for pipeline stage is 4, need to delay 3 cycles
    wire[7:0]                                           point_output_channel_sel_delay3,point_input_channel_sel_delay3;
    //dsu output, output from pointwise unit in dsu.
    wire[DATA_WIDTH*OUTCHANNEL_PARALLELISM-1:0]         DSU_outblock;
    //dsu input from pixel window, size of 3*3*DCP
    wire[DATA_WIDTH*3*3*CHANNEL_PARALLELISM-1:0]        DSU_inblock;
    //depthwise of a row in input feautre is done
    wire                                                depth_layer_done;
    //when a new 3*3 depthwise begins
    wire                                                depthwise_en;
    
    //pooling
    //1*2 pooling input from intermediate buffer2(P2P buffer)
    wire[DATA_WIDTH*POOL_PARALLELISM*2-1:0]            pool_infeature;
    //2*1 pooling output from pooling unit, i.e. 2*2 pooling output
    wire[DATA_WIDTH*POOL_PARALLELISM-1:0]              pool_outfeature;
    //pooling output feature position and current pooling channel, pool_channel_sel works like depth_channel_sel
    wire[7:0]                                          pool_outh,pool_outw,pool_channel_sel; 
    //when pooling of the whole feature is done   
    wire                                               pool_done; 
    //when a 1*2 pooling is done 
    wire                                                pool_channel_done;
    
    //input buffer: layer window, pixel window and feature memory
    //which col pixel window is updating
    wire[7:0]                                           inw;
    //init 3 row layer window 
    wire                                                init_buffer;
    //address of pixel from input feature in feature memory to layer buffer
    wire[12:0]                                          addr;
    // data fetched according to 'addr' -- 4 items once, when UCP is 4
    wire[DATA_WIDTH*UPDATE_PARALLELISM-1:0]             data;
     // init 3 row of layer window done
    wire                                                init_buffer_done;
    // feature mem works like a ping-pong buffer
    //--------------------------------------------------------------------
    //\ <-- first_feature_addr        \ <--  second_feature_addr          \
    //\                               \                                   \
    //\                               \                                   \
    //\                               \                                   \
    //--------------------------------------------------------------------
    //when a conv layer reads data from pos based on first_feature_addr, it's final outputs are written to pos based on second_feature_addr to avoid collision
    //when this conv layer finishes, second is filled with inputs of the 2nd conv layer, while first is empty
    //so 2nd conv layer starts reading from pos based on second_feature_addr and outputs are written to pos based on the first 
    
    //base addr in feature memory for diff conv layer 
    wire[12:0]                                          first_feature_addr = 13'h000;
    wire[12:0]                                          second_feature_addr = 13'h400;
    
    // address for pooling outdata to feature memory, height and width, for some timing reasons, need to delay 2 cycle
    reg[7:0]                                            pool_outh_delay=0,pool_outw_delay=0,pool_channel_sel_delay=0;
    reg[7:0]                                            pool_outh_delay2=0,pool_outw_delay2=0,pool_channel_sel_delay2=0;
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
    //addr for writing pooling results to feature memory
    wire[11:0]                      pool_outaddr;
    assign pool_outaddr = ((layer<4 || layer>7)?second_feature_addr[11:0]:first_feature_addr[11:0])+(output_size/2)*(output_channel/POOL_PARALLELISM)*(pool_outh_delay2) + (pool_outw_delay2)*(output_channel/POOL_PARALLELISM)+ pool_channel_sel_delay2/POOL_PARALLELISM;
  
    //base addr for diff conv layer, will add to addr in layer window 
    wire[12:0]                      base_addr;
    assign base_addr = (layer<4 || layer>7)?first_feature_addr*2:second_feature_addr*2;
    
    //feature memory -- porta for pool output write, portb for layer window read
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
   //update a column of data from layer window to pixel window, each has UCP items
    wire[DATA_WIDTH*UPDATE_PARALLELISM-1:0]             towindowdata0,towindowdata1,towindowdata2;
    //select channel to update in the 4th row in pixel window. 
    //if UCP is 4 and depth_channel=4, it means the new col in pixel window channel 4-8 is updating
    wire[7:0]                                           depth_channel;
    
    //layer window
    input_buffer_block 
    #(
    .DATA_WIDTH(DATA_WIDTH),
    .UPDATE_PARALLELISM(UPDATE_PARALLELISM),
    .PADDING(1)
    )
    ibb (
        //input port
        clk,
        init_buffer,
        depth_layer_done,
        layer,
        input_size,
        input_channel,
        inw,
        depth_channel,
        base_addr,
        data,
        //output port
        init_buffer_done,
        addr,
        towindowdata0,
        towindowdata1,
        towindowdata2
    );
    //pixel window update is done
    wire                        window_done;
    //init pixel window done after init buffer
    wire                        first_window_done;
    //indicate the first cycle of the last DCP channels of 3*3depthwise 
    wire                        first_cycle;
    //indicate when can begin next 3*3 depthwise while pointwise is doing
    wire                        next_en;
    
    pixel_window
    #(
    .DATA_WIDTH(DATA_WIDTH),  
    .PADDING(1),
    .UPDATE_PARALLELISM(UPDATE_PARALLELISM), 
    .CHANNEL_PARALLELISM(CHANNEL_PARALLELISM)
    )
    pixel_window(
    //input port
        clk,
        init_buffer,
        init_buffer_done,
        input_size,
        input_channel,
         depth_channel_sel,
        first_cycle,
        depthwise_en,
        towindowdata0,
        towindowdata1,
        towindowdata2,
        //output port
        inw,
        depth_channel,
        DSU_inblock,
        first_window_done,
        window_done   
    );
    //when point is doing, indicate when to write point output to intermediate buffer2
    wire                            point_doing;
    //from control unit, enable depthwise and pointwise
    wire                            depth_en,point_en;
    //signal the whole feature map depthwise and point done
    wire                            depth_done,point_done;
    // a pixel's pointwise done
    wire                            point11_done;
    
   //Depthwise Separable Convolution Unit
   DSU 
   #(
     .DATA_WIDTH(DATA_WIDTH), 
     .CHANNEL_PARALLELISM(CHANNEL_PARALLELISM), 
     .INCHANNEL_PARALLELISM(INCHANNEL_PARALLELISM), 
     .OUTCHANNEL_PARALLELISM(OUTCHANNEL_PARALLELISM)
    )
   DSU(
   //input port
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
        DSU_inblock,
    //output port
        depth_channel_sel,
        first_cycle,
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
    //when 1*2 pooling input is ready
    wire                            ibb2_done;
    //pooling position, indicate if it's end of a feature row
    wire[7:0]                       pool_inw;
    
   //P2P buffer
  intermediate_buffer2
  #(
  .DATA_WIDTH(DATA_WIDTH),  
  .OUTCHANNEL_PARALLELISM(OUTCHANNEL_PARALLELISM),  
  .POOL_PARALLELISM(POOL_PARALLELISM)
  )
  ibb2(
  //input port
        clk,
        pool_inw,
        layer,
        point_doing,
        point_output_channel_sel_delay3,
        point_input_channel_sel_delay3,
        pool_channel_sel,
        point11_done,
        DSU_outblock,
        //output port
        pool_infeature,
        ibb2_done
    );
   
   //pooling unit
   //the pooling unit is separate from depthwise separable conv unit
   pool 
   #(
    .DATA_WIDTH(DATA_WIDTH),  
    .POOL_PARALLELISM(POOL_PARALLELISM)
   )
   max_pool(
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
        pool_channel_done,
        pool_done
    );
    //flatten enable and done signal
   wire                             flatten_en,flatten_done;
   //address for pooling output written to flatten module
   wire[6:0]                        pool_addr;
   assign pool_addr = (output_size/2)*(output_channel/POOL_PARALLELISM)*(pool_outh_delay2) + (pool_outw_delay2)*(output_channel/POOL_PARALLELISM)+ pool_channel_sel_delay2/POOL_PARALLELISM;
   //full connected enable
   wire                             fc1_en,fc2_en;   
   
   //fc1 layer process is divided into x batch, y node. each step process y_i node -- input node number/x data inputs. e.g. 
   //1024*64 ->  32batch, 64 node,   one batch has 1024/32 = 32 data inputs.
   //each step processes one node and its corresponding 32 data inputs.
   //for every one node repeatedly process 32 times. 
   
   //fc2 layer is only divided into y node.
   
   //full connected layer 1 batch No.
   wire[4:0]                                fc1_batch;
   //full connected layer 1 node No.
   wire[5:0]                                fc1_node;
   //fc1 layer input data per step
   wire[32*DATA_WIDTH-1:0]                  fc1_indata,fc1_indata_copy;
   //fc layer done signal
   wire                                     fc1_done,fc2_done;
   //fc1 layer output
   wire[64*DATA_WIDTH-1:0]                  fc1_out;
   //fc1 layer weight addr for each step from weight bram
   wire[10:0]                               fc1_weight_addr;    
   assign fc1_weight_addr = fc1_node*32+fc1_batch; 
   //fc2 layer input data per step
   wire[64*DATA_WIDTH-1:0]                  fc2_weight,fc2_indata;
   assign fc2_indata = fc1_out;
   //fc2 layer input weight per step
   wire[32*DATA_WIDTH-1:0]                  fc1_weight,fc1_weight_copy;
   //fc2 layer 2 node number
   wire[3:0]                                fc2_node;
   //fc2 layer output
   wire[10*DATA_WIDTH-1:0]                  fc2_out;   
     
     //because of minor timing issue, need to delay some signals 1 cycle 
     reg                                    fc1_en_delay=0;
     always@(posedge clk)begin
        fc1_en_delay<=fc1_en;
     end
     assign fc1_indata_copy = fc1_en_delay?fc1_indata:0;
     assign fc1_weight_copy = fc1_en_delay?fc1_weight:0;
     
   //flatten unit
   flatten 
   #(
   .DATA_WIDTH(DATA_WIDTH),  
   .POOL_PARALLELISM(POOL_PARALLELISM)
   )
   flatten(
   //input port
        clk,
        layer,
        flatten_en,
        fc1_en,//enable to read fatten output to fc1 unit
        pool_outfeature,//output from pooling, which needs flattening
        pool_addr, 
        fc1_batch,//current fc1 address
        fc1_indata,
    //output port
        flatten_done     
     );
    //fc1 weight memory
     blk_mem_gen_3 fc1_weight_rom(
        .addra(fc1_weight_addr),
        .clka(clk),
        .douta(fc1_weight),
        .ena(fc1_en)
     );
    
     full_connect1 
     #(
     .DATA_WIDTH(DATA_WIDTH)
     )
     fc1(
           clk,
           layer,
           fc1_en,
           //inputs
           fc1_indata_copy,
           fc1_weight_copy,
           //current fc1 address
           fc1_batch,
           fc1_node,
           
           fc1_out,
           fc1_done
      );  
  
      blk_mem_gen_4 fc2_weight_rom(
        .addra(fc2_node),
        .clka(clk),
        .douta(fc2_weight),
        .ena(fc2_en)
      );

     full_connect2 
     #(
     .DATA_WIDTH(DATA_WIDTH)
     )
     fc2(
           clk,
           layer,//each layer has diff handling
           fc2_en,
           //inputs
           fc2_indata,
           fc2_weight,
           fc2_node,//current fc2 address
           fc2_out,
           fc2_done
      );
      
      control_unit cu(
      //input port
        clk,
        //process finishing signals, to step into next process
        init_buffer_done,
        depth_done,
        point_done,
        pool_done,
        fc1_done,
        fc2_done,
        flatten_done,
   //output port
        layer,//indicate which conv or fc layer is in
        DSU_en,//enable DSU to work
        depth_en,//enable depthwise
        point_en, //enable pointwise
        init_buffer, //enable init layer window
        fc1_en,//enable fc1
        fc2_en,//enable fc2
        flatten_en,//enable flatten
        //basic parameters
        input_size,
        output_size,
        input_channel,
        output_channel,
        feature_count
    );
    
    //fc2_done_count shows the number of feature completed
    reg[1:0]                    fc2_done_count=0;
    always@(posedge clk)begin
        if(fc2_done)
            fc2_done_count<=fc2_done_count==3?3:fc2_done_count+1;
    end
    //results on 10 classes
    always@(posedge clk)begin
        if(fc2_done&&fc2_done_count<3)begin
         out[0] <= fc2_out[DATA_WIDTH*0+15];
         out[1] <= fc2_out[DATA_WIDTH*1+15];
         out[2] <= fc2_out[DATA_WIDTH*2+15];
         out[3] <= fc2_out[DATA_WIDTH*3+15];
         out[4] <= fc2_out[DATA_WIDTH*4+15];
         out[5] <= fc2_out[DATA_WIDTH*5+15];
         out[6] <= fc2_out[DATA_WIDTH*6+15];
         out[7] <= fc2_out[DATA_WIDTH*7+15];
         out[8] <= fc2_out[DATA_WIDTH*8+15];
         out[9] <= fc2_out[DATA_WIDTH*9+15];
        end
    end
    
endmodule
