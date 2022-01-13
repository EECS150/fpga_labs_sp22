SHELL                   := $(shell which bash) -o pipefail
ABS_TOP                 := $(subst /cygdrive/c/,C:/, $(shell pwd))
SCRIPTS                 := $(ABS_TOP)/../scripts
VIVADO                  ?= vivado
VIVADO_OPTS             ?= -nolog -nojournal -mode batch
FPGA_PART               ?= xc7z020clg400-1
RTL                     += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f -name "*.v"))
CONSTRAINTS             += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f -name "*.xdc"))
TOP                     ?= z1top
VCS                     := vcs -full64
VCS_OPTS                := -notice -line +lint=all,noVCDE,noNS,noSVA-UA -sverilog -timescale=1ns/10ps -debug
SIM_RTL                 := $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/sim -type f -name "*.v"))
IVERILOG                := iverilog
IVERILOG_OPTS           := -D IVERILOG=1 -g2012 -gassertions -Wall -Wno-timescale
VVP                     := vvp

sim/%.tb: sim/%.v $(RTL)
	cd sim && $(VCS) $(VCS_OPTS) -o $*.tb $(RTL) $*.v -top $*

sim/%.vpd: sim/%.tb
	cd sim && ./$*.tb +verbose=1 +vpdfile+$*.vpd

sim/%.tbi: sim/%.v $(RTL)
	cd sim && $(IVERILOG) $(IVERILOG_OPTS) -o $*.tbi $*.v $(RTL)

sim/%.fst: sim/%.tbi
	cd sim && $(VVP) $*.tbi -fst

build/target.tcl: $(RTL) $(CONSTRAINTS)
	mkdir -p build
	truncate -s 0 $@
	echo "set ABS_TOP                        $(ABS_TOP)"    >> $@
	echo "set TOP                            $(TOP)"    >> $@
	echo "set FPGA_PART                      $(FPGA_PART)"  >> $@
	echo "set_param general.maxThreads       4"    >> $@
	echo "set_param general.maxBackupLogs    0"    >> $@
	echo -n "set RTL { " >> $@
	FLIST="$(RTL)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set CONSTRAINTS { " >> $@
	FLIST="$(CONSTRAINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@

setup: build/target.tcl

elaborate: build/target.tcl $(SCRIPTS)/elaborate.tcl
	mkdir -p ./build
	cd ./build && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/elaborate.tcl |& tee elaborate.log

build/synth/$(TOP).dcp: build/target.tcl $(SCRIPTS)/synth.tcl
	mkdir -p ./build/synth/
	cd ./build/synth/ && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/synth.tcl |& tee synth.log

synth: build/synth/$(TOP).dcp

build/impl/$(TOP).bit: build/synth/$(TOP).dcp $(SCRIPTS)/impl.tcl
	mkdir -p ./build/impl/
	cd ./build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/impl.tcl |& tee impl.log

impl: build/impl/$(TOP).bit
all: build/impl/$(TOP).bit

program: build/impl/$(TOP).bit $(SCRIPTS)/program.tcl
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl

program-force:
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl

vivado: build
	cd build && nohup $(VIVADO) </dev/null >/dev/null 2>&1 &

lint:
	verilator --lint-only --top-module $(TOP) $(RTL)

sim_build/compile_simlib/synopsys_sim.setup:
	mkdir -p sim_build/compile_simlib
	cd build/sim_build/compile_simlib && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/compile_simlib.tcl

compile_simlib: sim_build/compile_simlib/synopsys_sim.setup

clean:
	rm -rf ./build $(junk) *.daidir sim/output.txt \
	sim/*.tb sim/*.daidir sim/csrc \
	sim/ucli.key sim/*.vpd sim/*.vcd \
	sim/*.tbi sim/*.fst sim/*.jou sim/*.log sim/*.out

.PHONY: setup synth impl program program-force vivado all clean %.tb
.PRECIOUS: sim/%.tb sim/%.tbi sim/%.fst sim/%.vpd
