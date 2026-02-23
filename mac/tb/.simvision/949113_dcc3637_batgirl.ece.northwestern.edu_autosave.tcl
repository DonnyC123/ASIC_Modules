
# XM-Sim Command File
# TOOL:	xmsim(64)	21.09-s001
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
set vcd_compact_mode 0
alias . run
alias quit exit
stop -create -name Randomize -randomize
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_mac_float.a tb_mac_float.b tb_mac_float.c tb_mac_float.errors tb_mac_float.i tb_mac_float.real_a tb_mac_float.real_b tb_mac_float.real_c tb_mac_float.real_z_dut tb_mac_float.real_z_ref tb_mac_float.z tb_mac_float.dut.a tb_mac_float.dut.b tb_mac_float.dut.c tb_mac_float.dut.c_dominates tb_mac_float.dut.c_upper_slice tb_mac_float.dut.csa_c tb_mac_float.dut.csa_summands tb_mac_float.dut.csa_tree_carry tb_mac_float.dut.csa_tree_sum tb_mac_float.dut.float_a tb_mac_float.dut.float_b tb_mac_float.dut.float_c tb_mac_float.dut.float_z tb_mac_float.dut.guard tb_mac_float.dut.mantissa_sum_lower tb_mac_float.dut.mantissa_sum_lz tb_mac_float.dut.mantissa_sum_raw tb_mac_float.dut.mantissa_sum_raw_neg tb_mac_float.dut.mantissa_sum_shift tb_mac_float.dut.mantissa_sum_upper tb_mac_float.dut.normalized_mantissa tb_mac_float.dut.partial_products tb_mac_float.dut.product_exp tb_mac_float.dut.product_sign tb_mac_float.dut.round_mantissa tb_mac_float.dut.sticky_c tb_mac_float.dut.sticky_sum tb_mac_float.dut.sum_exp tb_mac_float.dut.sum_exp_ovfl tb_mac_float.dut.sum_exp_unfl tb_mac_float.dut.sum_frac_carry tb_mac_float.dut.sum_frac_raw tb_mac_float.dut.sum_frac_rounded tb_mac_float.dut.sum_inf tb_mac_float.dut.sum_inf_sign tb_mac_float.dut.sum_nan tb_mac_float.dut.sum_rounded_exp tb_mac_float.dut.sum_rounded_exp_ovfl tb_mac_float.dut.sum_rounded_exp_unfl tb_mac_float.dut.sum_signed tb_mac_float.dut.unpacked_a tb_mac_float.dut.unpacked_b tb_mac_float.dut.unpacked_c tb_mac_float.dut.unsigned_mantissa_sum tb_mac_float.dut.upper_sum_temp tb_mac_float.dut.z

simvision -input /home/dcc3637/Floating_Point_Modules/mac/tb/.simvision/949113_dcc3637_batgirl.ece.northwestern.edu_autosave.tcl.svcf
