XRUN = xrun
FLAGS = -64bit -sv -f run.f -timescale 1ns/1ps -access +rwc

all: run

run:
	$(XRUN) $(FLAGS) -top tb_divider_float

gui:
	$(XRUN) $(FLAGS) -top tb_divider_float -gui

clean:
	rm -rf xcelium.d xrun.history xrun.log waves.shm

