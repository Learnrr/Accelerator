// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Mon Sep  1 16:39:43 2025
// Host        : DESKTOPRFLO5M9 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               D:/myproject/project_min_resources_8bit_n4_p2/project_10.srcs/sources_1/ip/blk_mem_gen_3/blk_mem_gen_3_stub.v
// Design      : blk_mem_gen_3
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module blk_mem_gen_3(clka, ena, addra, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,addra[10:0],douta[255:0]" */;
  input clka;
  input ena;
  input [10:0]addra;
  output [255:0]douta;
endmodule
