XRUN = xrun
TOP  = divider_float_tb

BASE_FLAGS = -64bit -sv -timescale 1ns/1ps -access +rwc

.PHONY: all run-16 run-32 gui-16 gui-32 clean

all: run-16

run-16:
	$(XRUN) $(BASE_FLAGS) -f ../file_list/divider_float_16_rtl.f -f ../file_list/divider_float_16_tb.f divider_float_16_tb.sv -top $(TOP) -l xrun_16bit.log

run-32:
	$(XRUN) $(BASE_FLAGS) -f ../file_list/divider_float_32_rtl.f -f ../file_list/divider_float_32_tb.f divider_float_32_tb.sv -top $(TOP) -l xrun_32bit.log

gui-16:
	$(XRUN) $(BASE_FLAGS) -f ../file_list/divider_float_16_rtl.f -f ../file_list/divider_float_16_tb.f divider_float_16_tb.sv -top $(TOP) -gui

gui-32:
	$(XRUN) $(BASE_FLAGS) -f ../file_list/divider_float_32_rtl.f -f ../file_list/divider_float_32_tb.f divider_float_32_tb.sv -top $(TOP) -gui

clean:
	@echo "Cleaning simulation files..."
	rm -rf xcelium.d xrun.history xrun*.log waves.shm *.err
