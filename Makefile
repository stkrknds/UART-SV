##
# UART
#

RTL_DIR := rtl
TB_DIR := tb
BIN_DIR := bin

SIM_MODULE := uart_tb

RTL := $(wildcard $(RTL_DIR)/*.sv)
TB := $(wildcard $(TB_DIR)/*.sv)

COMPILER := vlog
COMPFLAGS := -work $(BIN_DIR)

SIMULATOR := vsim
SIMFLAGS := -c -work $(BIN_DIR) -nolog

.PHONY: sim compile gui clean

sim:
	$(MAKE) compile
	$(SIMULATOR) $(SIMFLAGS) $(SIM_MODULE) -do 'run -all; quit'

compile: $(RTL) $(TB) | $(BIN_DIR)
	$(COMPILER) $(COMPFLAGS) $^

gui:
	$(SIMULATOR) -do sim.tcl -nolog

$(BIN_DIR):
	mkdir -p bin

clean:
	rm -rf $(BIN_DIR)
	rm -f vsim.wlf
# end
