# Accelerator
Exploiting Two-Level Pipeline and Triple Sliding-Window Input Buffer for Efficient DSC Accelerator Design
## Description
This is the source code of our accelerator. Master branch is the true form version while project_2 branch is the 2's complement code version. 

In true form version we can see the results straightly but it takes much more logics to deal with the sign bit, so it has a larger resource usage and lower frequency (30Mhz). However, it has the correct functional simulation and can be directly employed onto your FPGA board to see the correct results. This version also has a good organization and clear code comments in order to help you to understand.

Project_2 branch is the 2's complement code version and has good performance but until now the functional simulation has not been completed yet. It can go through all the network layers in a expected way but we don't know if the result is correct. Though it's raw code and may be hard to understand, it's almost the same as master branch except for the multiplication and addition operations. After the functional simulation is finished, this branch will be updated.

## Project version
IDE: Vivado 2019.2  
FPGA: ZYNQ-7020

## Abstract
Convolutional Neural Networks (CNNs) are widely used, yet their increasing depth poses significant deployment challenges for embedded devices. Depthwise separable convolution (DSC) offers a lightweight alternative by reducing computation and parameters with minimal accuracy loss. However, many existing FPGA implementations prioritize performance over resource efficiency, leading to high memory latency, low utilization, and elevated power consumption. 

This paper introduces a novel FPGA accelerator that addresses these limitations through three co-designed optimizations: A triple sliding-window input buffer design is proposed which could leverage data locality to exploit the parallelism between memory access and computation, thereby reducing latency; A scalable DSC processing unit with adjustable parallelism is designed to meet diverse resource constraints; A two-level nested pipeline is proposed to operate on full channels (outer) and convolution phases (inner), thus effectively minimizing idle time.

Our theoretical runtime analysis demonstrates significant performance gains: the proposed computational and buffering parallelism strategy achieves a 50x speedup in buffering, and the two-level pipeline yields a 6.4x speedup in computation compared to non-parallel and unpipelined approaches, respectively. Implemented on limited resources, the proposed design achieves 7165 FPS at 133MHz with 0.3W power, matching or exceeding prior work. Experiments further analyze the frequency-pipeline-stage-power relationship, indicating that frequency increases sublinearly with pipeline depth, while power scales with both depth and frequency. Results reveal an optimal frequency-power ratio as pipeline depth increases for DSC units.

## Project structure
The file organization is as follows.

Accelerator  
|----assets  
|&emsp;&emsp;|----examples  
|----srcs  
|&emsp;&emsp;|----constrs_1  
|&emsp;&emsp;|----sim_1  
|&emsp;&emsp;|----sources_1  
|&emsp;&emsp;&emsp;&emsp;|----ip  
|&emsp;&emsp;&emsp;&emsp;|----new  
|----weights  
|----build.bat  
|----build.tcl  
`assets` dir contains some pictures used for this readme and examples. The `srcs` dir contains the contraint files `constrs_1`, simulation files `sim_1`, and HDL files `sources_1`. The `weights` dir contains the weight coe files and bias files for ram/rom IP initialization.  `build.bat` and `build.tcl` are for building project.

## How to start
1. clone the repository.  
you need to clone the project to your local machine.  
`git clone https://github.com/Learnrr/accelerator.git`

2. build the project. refer to[Version control for Vivado projects](https://www.fpgadeveloper.com/2014/08/version-control-for-vivado-projects.html/).  
you can use Tcl script to build the project. For windows you can just double click to run the `build.bat` and it should contain:  
`your vivado.bat path -mode batch -source build.tcl`  
Then open the project by clicking on the generated .xpr file.  
Another way is to run the .bat file from Vivado welcome screen. Just select Window->Tcl Console, use `cd` to enter the project dir and execute the build script.
`source build.tcl`

3. update initialization for ram.  
you may need to update the weight coe files for some IPs and bias files for bias rom. The weight and bias files are in `weight` dir. They are from Pytorch and already quantified into 8(project2 branch)/16(master branch) bits using symmetric method. In order to find the bias rom location, you can go to `depthwise.v`, `pointwise.v` and `full_connect.v` in `srcs/sources_1/new` to update the bias initialization file path.

4. run the project.  
Now you can run simulation, synthesis, implementation, or deploy it onto your FPGA board.

## System architecture and dataflow
The architecture overview of the accelerator is shown as the following picture.  
![architecture](/assets/architecture.jpg)
The main file organization of the accelerator HDL is shown in the follows. If you build the project through the procedures in 'How to start' you will see this.  
|----TOP   
|&emsp;&emsp;|----bram0                       &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;-----------  
|&emsp;&emsp;|----input_buffer_block                            &emsp;&emsp;&emsp;&emsp;   &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;  |     Triple sliding-window input_buffer  
|&emsp;&emsp;|----pixel_window    &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;          -----------  
|&emsp;&emsp;|----DSU                         &emsp;&emsp;&emsp;&emsp;  &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;              -----------  
|&emsp;&emsp;|&emsp;&emsp;|---- depth_weight_rom       &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;              |  
|&emsp;&emsp;|&emsp;&emsp;|----depthwise          &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;                    |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|----compute_engine       &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;       |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|&emsp; ......          &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;  &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;       |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|----compute_engine     &emsp;&emsp;&emsp;&emsp;  &emsp;&emsp;       |         Depthwise Separable Convolution Unit  
|&emsp;&emsp;|&emsp;&emsp;|----intermediate_buffer             &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;      |  
|&emsp;&emsp;|&emsp;&emsp;|----- point_weight_rom             &emsp;&emsp;&emsp;&emsp;   &emsp;&emsp;&emsp;       |  
|&emsp;&emsp;|&emsp;&emsp;|---- pointwise                        &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;         |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|----compute_engine_p   &emsp;&emsp;&emsp;&emsp; &emsp;        |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|&emsp; ........            &emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp; &emsp; &emsp; &emsp; &emsp;          |  
|&emsp;&emsp;|&emsp;&emsp;|&emsp;&emsp;|----compute_engine_p  &emsp;&emsp;&emsp; -------  
|&emsp;&emsp;|----intermediate_buffer2     
|&emsp;&emsp;|----pool                                     &emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;  -----------  
|&emsp;&emsp;|&emsp;&emsp;|---- max_pool                     &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;            |      1\*2 + 2\*1 pooling Unit  
|&emsp;&emsp;|&emsp;&emsp;|&emsp; ...                     &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp; &emsp;&emsp;&emsp;           |  
|&emsp;&emsp;|&emsp;&emsp;|----max_pool                    &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;   -----------  
|&emsp;&emsp;|----flatten                                &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;-------------                  flatten unit  
|&emsp;&emsp;|  
|&emsp;&emsp;|----fc1_weight_rom                       &emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;&emsp;    ---------|  full_connect1 unit  
|&emsp;&emsp;|----full_connect1                         &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;      ----------|  
|&emsp;&emsp;|  
|&emsp;&emsp;|----fc2_weight_rom                        &emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;     ----------|  full connect2 unit  
|&emsp;&emsp;|----full_connect2                         &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;      -----------|  
|&emsp;&emsp;|----control_unit                           &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; -------------                      control unit  

Though all the files, they actually can be divided into 7 basic parts:   
- Triple sliding-window input buffer
- Depthwise Separable Convolution Unit
- Pooling unit
- flatten unit
- full connect1 unit
- full connect2 unit
- control unit

### Triple sliding-window input buffer
- 'bram0' is the on-chip feature memory which stores the quantified feature maps and it's the source of triple sliding-window input buffer.
- 'input_buffer_block' is the Layer Window.
- 'pixel_window' do the function of Pixel Window and Channel Window.
### Depthwise Separable Convolution Unit
- Depthwise separable convolution unit consists of depthwise computation unit and its weight rom, pointwise computation unit and its weight rom, and the D2P buffer which stores the partial-channel depthwise results.
- The depthwise computation unit is implemented in the file 'depthwise'. The unit reads feature map from Channel Window and has 'DCP' computing engines with each computes one channel of window convolution.
- The D2P buffer is implemented in the file 'intermediate_buffer'. It stores 'DCP' channels' coming out of depthwise unit. When all the channels' result are completed, it starts to push the data to pointwise unit.
- The pointwse computation unit is implemented in the file 'pointwise'. The unit reads data from D2P_buffer and do the pointwise process. It has 'OCP' computing engines with each computes 'ICP' input channels.
### Pooling unit
- Pooling unit consists of several pooling engines and pooling buffer, which are all implemented in the file 'pool'.
- Pooing unit works relying on P2P buffer which is wriiten in the file 'intermediate_buffer2'. Outputs of pointwise unit is of dimension 1\*1\*OCP but inputs required by pooling unit is of dimension 1\*2\*PCP, so it's the P2P buffer do the medium function. P2P buffer accumulates outputs of pointwise unit and when 1\*2 inputs are ready, it starts to feed the data to pooling unit.
- The pooling buffer stores the 1\*2 pooling result and provide inputs for 2\*1 pooling.
- Pooling engine is actually a comparator in max-pool. Thus, every time 1\*2\*PCP or 2\*1\*PCP inputs come, the 'PCP' pooling engines pick the larger one in each channel. In odd rows, pooling unit only do the 1\*2 pooling and stores the results to pooling buffer. In even rows, the unit first do the 1\*2 pooling and make a comparison between this result and the last odd-row result in the same column to complete the 2\*1 pooling.
### Flatten unit
The flatten unit uses a 2-bank method, which is illustrated in the picture below.
![flatten](/assets/flatten.jpg)
### Full connect unit
The full connect units a node-batch method. We divide all input node into several batches, use a double cyculation algorithm to calculate output node one by one.
![full_connect](/assets/full_connect.jpg)
![fc_algorithm](/assets/fc_algorithm.jpg)
### Control unit
The control unit works as a finite state machine. It receives signals from other modules to see the working status and send signals to control the working status.
### Dataflow
The dataflow of the main parts(Triple sliding-window input buffer, Depthwise Separable Convolution Unit, Pooling unit) is shown in the picture below.
![dataflow](/assets/dataflow.jpg)
## Examples
The project now has 3 picture files in 'coe' file type, 'plane.coe', 'ship.coe' and 'car.coe' which are generated by Pytorch. You can make a initialization of 'bram0' using these files.
