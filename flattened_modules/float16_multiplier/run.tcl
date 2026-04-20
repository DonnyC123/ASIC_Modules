# Runtime TCL for xmsim — executed by xrun -input after elaboration.
# Dumps waves to waves.shm, runs the testbench to completion, exits.

database -open waves -into waves.shm -default
probe    -create float16_multiplier_tb -depth all -shm
run
exit
