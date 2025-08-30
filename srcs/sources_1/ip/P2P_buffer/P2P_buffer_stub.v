// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Fri May  9 10:24:23 2025
// Host        : DESKTOPRFLO5M9 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top P2P_buffer -prefix
//               P2P_buffer_ P2P_buffer_stub.v
// Design      : P2P_buffer
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module P2P_buffer(clka, ena, wea, addra, dina, clkb, enb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[0:0],addra[2:0],dina[63:0],clkb,enb,addrb[2:0],doutb[63:0]" */;
  input clka;
  input ena;
  input [0:0]wea;
  input [2:0]addra;
  input [63:0]dina;
  input clkb;
  input enb;
  input [2:0]addrb;
  output [63:0]doutb;
endmodule
