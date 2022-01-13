source ../target.tcl
open_hw

connect_hw_server -url localhost:3121
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
set_property PARAM.FREQUENCY 15000000 [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target

current_hw_device [get_hw_devices xc7z*]
set_property PROBES.FILE {} [get_hw_devices xc7z*]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7z*]

# Hack to expand ${ABS_TOP} and ${TOP} properly, running set_property directly doesn't expand these variables
set set_cmd "set_property PROGRAM.FILE \{${ABS_TOP}/build/impl/${TOP}.bit\} \[get_hw_devices xc7z*\]"
eval ${set_cmd}
program_hw_devices [get_hw_devices xc7z*]
refresh_hw_device [get_hw_devices xc7z*]

close_hw
