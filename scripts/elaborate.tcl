source ./target.tcl

# Read Verilog source files
if {[string trim ${RTL}] ne ""} {
  read_verilog -v ${RTL}
}

# Read user constraints
if {[string trim ${CONSTRAINTS}] ne ""} {
  read_xdc ${CONSTRAINTS}
}

# Only elaborate RTL (don't synthesize to netlist)
synth_design -top ${TOP} -part ${FPGA_PART} -rtl

# write_checkpoint doesn't work:
# Vivado% write_checkpoint -force z1top_post_elab.dcp
# ERROR: [Common 17-69] Command failed: Checkpoints are not supported for RTL designs

# Open the schematic visualization
start_gui
