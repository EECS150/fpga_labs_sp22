source ../target.tcl
open_hw_manager

connect_hw_server -url localhost:3121 -allow_non_jtag
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
set_property PARAM.FREQUENCY 15000000 [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target

current_hw_device [get_hw_devices xc7z*]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z*] 0]
set_property PROBES.FILE {} [get_hw_devices xc7z020_1]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7z020_1]

# Hack to expand ${ABS_TOP} and ${TOP} properly, running set_property directly doesn't expand these variables
set set_cmd "set_property PROGRAM.FILE \{${ABS_TOP}/build/impl/${TOP}.bit\} \[get_hw_devices xc7z*\]"
eval ${set_cmd}
program_hw_devices [get_hw_devices xc7z*]
refresh_hw_device [lindex [get_hw_devices xc7z*] 0]

close_hw_manager

# Raw TCL and log
# start_gui
# open_hw_manager
# INFO: [IP_Flow 19-234] Refreshing IP repositories
# INFO: [IP_Flow 19-1704] No user IP repositories specified
# INFO: [IP_Flow 19-2313] Loaded Vivado IP repository '/opt/vivado/Vivado/2021.1/data/ip'.
# open_hw_manager: Time (s): cpu = 00:00:14 ; elapsed = 00:00:05 . Memory (MB): peak = 7493.453 ; gain = 58.125 ; free physical = 12289 ; free virtual = 35691
# connect_hw_server -url localhost:3121 -allow_non_jtag
# INFO: [Labtools 27-2285] Connecting to hw_server url TCP:localhost:3121
# INFO: [Labtools 27-3415] Connecting to cs_server url TCP:localhost:3042
# INFO: [Labtools 27-3414] Connected to existing cs_server.
# current_hw_target [get_hw_targets */xilinx_tcf/Digilent/003017A8B74BA]
# set_property PARAM.FREQUENCY 15000000 [get_hw_targets */xilinx_tcf/Digilent/003017A8B74BA]
# open_hw_target
# INFO: [Labtoolstcl 44-466] Opening hw_target localhost:3121/xilinx_tcf/Digilent/003017A8B74BA
# current_hw_device [get_hw_devices xc7z020_1]
# refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z020_1] 0]
# INFO: [Labtools 27-1434] Device xc7z020 (JTAG device index = 1) is programmed with a design that has no supported debug core(s) in it.
# set_property PROBES.FILE {} [get_hw_devices xc7z020_1]
# set_property FULL_PROBES.FILE {} [get_hw_devices xc7z020_1]
# set_property PROGRAM.FILE {/home/vighnesh/10-school/12-secondary/19-eecs151/labs_skeleton/fpga_labs_fa21/lab1/build/impl/z1top.bit} [get_hw_devices xc7z020_1]
# program_hw_devices [get_hw_devices xc7z020_1]
# INFO: [Labtools 27-3164] End of startup status: HIGH
# refresh_hw_device [lindex [get_hw_devices xc7z020_1] 0]
# INFO: [Labtools 27-1434] Device xc7z020 (JTAG device index = 1) is programmed with a design that has no supported debug core(s) in it.
# close_hw_manager
# ****** Webtalk v2021.1 (64-bit)
#   **** SW Build 3247384 on Thu Jun 10 19:36:07 MDT 2021
#   **** IP Build 3246043 on Fri Jun 11 00:30:35 MDT 2021
#     ** Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
#
# source /home/vighnesh/10-school/12-secondary/19-eecs151/labs_skeleton/fpga_labs_fa21/lab1/build/.Xil/Vivado-186575-vighnesh-t480/webtalk/labtool_webtalk.tcl -notrace
# INFO: [Common 17-186] '/home/vighnesh/10-school/12-secondary/19-eecs151/labs_skeleton/fpga_labs_fa21/lab1/build/.Xil/Vivado-186575-vighnesh-t480/webtalk/usage_statistics_ext_labtool.xml' has been successfully sent to Xilinx on Fri Aug 27 17:02:08 2021. For additional details about this file, please refer to the WebTalk help file at /opt/vivado/Vivado/2021.1/doc/webtalk_introduction.html.
# INFO: [Common 17-206] Exiting Webtalk at Fri Aug 27 17:02:08 2021...
# close_hw_manager: Time (s): cpu = 00:00:09 ; elapsed = 00:00:08 . Memory (MB): peak = 8461.398 ; gain = 7.219 ; free physical = 10648 ; free virtual = 34132
