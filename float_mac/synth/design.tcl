# =============================================================================
# Design config: mac_float  (float16 MAC)
# =============================================================================
set SCRIPT_DIR    [file dirname [file normalize [info script]]]
set REPO_ROOT     [file normalize $SCRIPT_DIR/../..]

set DESIGN_NAME   mac_float
set CLK_PORT      clk
set CLK_PERIOD_NS 1.8

set RUN_F         [file normalize $SCRIPT_DIR/../tb/run.f]
set WORK_DIR      $SCRIPT_DIR/out

# set TECH_LIB /path/to/your/lib.lib

source $REPO_ROOT/common/scripts/synth.tcl
