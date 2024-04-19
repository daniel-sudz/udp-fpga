# -Wall turns on all warnings
# -g2012 selects the 2012 version of iVerilog
SHELL=/bin/bash
IVERILOG=iverilog -g2012 -Wall -y ./hdl -I ./hdl
IVERILOG_SIM_ARGS= -y ./tests -I ./tests
VVP=vvp
VVP_POST=-fst
VIVADO=vivado -mode batch -source
WAVES=gtkwave --rcvar 'fontname_signals Monospace 10' --rcvar 'fontname_waves Monospace 10'


MAIN_DEPS= *.memh
MAIN_SRCS= hdl/*.sv hdl/main.sv

# .PHONY dereferences possible files named "clean" and instead runs it as cmd
.PHONY: clean usb

# test_main: hdl/tests/test_main.sv hdl/main.sv ${MAIN_SRCS}
# 	@echo "This might take a while, we're testing a lot of clock cycles!"
# 	${IVERILOG} $^ -o test_main.bin && ${VVP} test_main.bin ${VVP_POST}
# waves_main : test_main hdl/tests/main.gtkw
# 	${WAVES} -a hdl/tests/main.gtkw main.fst


# main.bit: ${MAIN_SRC} ${MAIN_DEPS}
# 	@echo "################################################"
# 	@echo "## building Main with..."
# 	@echo "## 	SRC=$(MAIN_SRC)"
# 	@echo "## 	DEPS=$(MAIN_DEPS)"
# 	@echo "################################################"
# 	SYNTH_HDL_SOURCES="main.sv $(MAIN_SRC)" SYNTH_XDC_FILE="main.xdc" SYNTH_TOP_MODULE="main" ${VIVADO} build.tcl

# main.program: main.bit 
# 	${VIVADO} program.tcl

main.bit: $(MAIN_SRCS) $(MAIN_DEPS)
	@echo "########################################"
	@echo "#### Building FPGA bitstream        ####"
	@echo "########################################"
	SYNTH_HDL_SOURCES="main.sv $(MAIN_SRC)" SYNTH_XDC_FILE="main.xdc" SYNTH_TOP_MODULE="main" ${VIVADO} build.tcl

program_fpga_vivado: main.bit
	@echo "########################################"
	@echo "#### Programming FPGA (Vivado)      ####"
	@echo "########################################"
	${VIVADO} program.tcl

program_fpga_digilent: main.bit
	@echo "########################################"
	@echo "#### Programming FPGA (Digilent)    ####"
	@echo "########################################"
	djtgcfg enum
	djtgcfg prog -d ArtyA7 -i 0 -f main.bit


# Call this to clean up all generated files
clean:
	rm -f *.bin *.vcd *.fst vivado*.log *.jou vivado*.str *.log *.checkpoint *.bit *.html *.xml
	rm -rf .Xil
usb:
	picocom -b 115200 --omap crcrlf /dev/ttyUSB1

#main test
test_udp_main: tests/test_udp_main.sv hdl/udp_main.sv
	${IVERILOG} -o $@.bin $^ && ${VVP} $@.bin ${VVP_POST}
waves_test_udp_main : test_udp_main
	${WAVES} test_udp_main.fst

#main cocotb tests
test_coco_main:
	SIM=icarus python -m pytest -o log_cli=True tests/test_udp_main.py