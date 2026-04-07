# =============================================================================
# Design config: mac_float_mixed  (FP16 in -> FP32 out MAC)
# =============================================================================
set SCRIPT_DIR    [file dirname [file normalize [info script]]]
set REPO_ROOT     [file normalize $SCRIPT_DIR/../..]

set DESIGN_NAME   mac_float_mixed
set CLK_PORT      clk
set CLK_PERIOD_NS 1.8

set RUN_F         [file normalize $SCRIPT_DIR/../file_list/mac_float_16i_32o_rtl.f]
set WORK_DIR      $SCRIPT_DIR/out_mixed

# set TECH_LIB /path/to/your/lib.lib

source $REPO_ROOT/common/scripts/synth.tcl
