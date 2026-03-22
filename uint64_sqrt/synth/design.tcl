# =============================================================================
# Design config: srt_sqrt  (uint64 SRT radix-4 square root)
# =============================================================================
set SCRIPT_DIR    [file dirname [file normalize [info script]]]
set REPO_ROOT     [file normalize $SCRIPT_DIR/../..]

set DESIGN_NAME   srt_sqrt
set CLK_PORT      clk
set CLK_PERIOD_NS 2.0

# Sim run.f lives next to the Makefile; TB top is filtered automatically
set RUN_F         [file normalize $SCRIPT_DIR/../run.f]
set WORK_DIR      $SCRIPT_DIR/out

# set TECH_LIB /path/to/your/lib.lib   ;# or setenv TECH_LIB before invoking

source $REPO_ROOT/common/scripts/synth.tcl
