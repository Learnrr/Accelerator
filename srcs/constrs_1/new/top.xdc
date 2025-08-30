create_clock -period 17.500 -name sys_clk2 -waveform {0.000 8.750} -add [get_ports clk2]
create_clock -period 7.500 -name sys_clk -waveform {0.000 3.750} -add [get_ports clk]






















set_false_path -reset_path -from [get_clocks sys_clk2] -to [get_clocks sys_clk]
set_false_path -reset_path -from [get_clocks sys_clk] -to [get_clocks sys_clk2]




















set_operating_conditions -grade extended
