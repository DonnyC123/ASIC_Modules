XRUN = xrun
FLAGS = -64bit -sv -f run.f -timescale 1ns/1ps -access +rwc

all: run

run:
	$(XRUN) $(FLAGS) -top sqrt_tb

gui:
	$(XRUN) $(FLAGS) -top sqrt_tb -gui

clean:
	rm -rf xcelium.d xrun.history xrun.log waves.shm

