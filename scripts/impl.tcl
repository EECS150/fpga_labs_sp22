source ../target.tcl

open_checkpoint ${ABS_TOP}/build/synth/${TOP}.dcp

if {[string trim ${CONSTRAINTS}] ne ""} {
  read_xdc ${CONSTRAINTS}
}

opt_design
place_design
write_checkpoint -force ${TOP}_placed.dcp
report_utilization -file post_place_utilization.rpt
phys_opt_design
route_design

write_checkpoint -force ${TOP}_routed.dcp
write_verilog -force post_route.v
write_xdc -force post_route.xdc
report_drc -file post_route_drc.rpt
report_timing_summary -warn_on_violation -file post_route_timing_summary.rpt

write_bitstream -force ${TOP}.bit
