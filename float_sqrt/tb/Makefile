XRUN = xrun

BITWIDTH ?= 16

TB_FILE = sqrt_float_$(BITWIDTH)_tb.sv

TOP = sqrt_float_tb

FLAGS = -64bit -sv -f run.f $(TB_FILE) -timescale 1ns/1ps -access +rwc -l xrun_$(BITWIDTH)bit.log

.PHONY: all run gui clean check_tb

all: run

check_tb:
	@if [ ! -f $(TB_FILE) ]; then \
		echo "ERROR: Testbench file $(TB_FILE) not found!"; \
		exit 1; \
	fi

run: check_tb
	@echo "Running simulation for $(BITWIDTH)-bit configuration..."
	$(XRUN) $(FLAGS) -top $(TOP)

gui: check_tb
	@echo "Opening GUI for $(BITWIDTH)-bit configuration..."
	$(XRUN) $(FLAGS) -top $(TOP) -gui

clean:
	@echo "Cleaning simulation files..."
	rm -rf xcelium.d xrun.history xrun*.log waves.shm *.err
