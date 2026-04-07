# =============================================================================
# Design config: mac_float  (float16 MAC)
# =============================================================================
set SCRIPT_DIR    [file dirname [file normalize [info script]]]
set REPO_ROOT     [file normalize $SCRIPT_DIR/../..]

set DESIGN_NAME   mac_float
set CLK_PORT      clk
set CLK_PERIOD_NS 2.0

set RUN_F         [file normalize $SCRIPT_DIR/../file_list/mac_float_16_rtl.f]
set WORK_DIR      $SCRIPT_DIR/out


source $REPO_ROOT/common/scripts/synth.tcl
