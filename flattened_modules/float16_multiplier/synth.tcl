
set_db hdl_search_path { . }
read_hdl -v [list \
    float16_decoder.v \
    leading_zero_counter.v \
    product_normalizer.v \
    product_rounder.v \
    float16_multiplier.v \
]

elaborate float16_multiplier
check_design -unresolved

set_max_delay 5.0 -from [all_inputs] -to [all_outputs]

syn_generic
syn_map
syn_opt

report_timing > synth/timing.rpt
report_area   > synth/area.rpt
report_gates  > synth/gates.rpt
report_power  > synth/power.rpt

write_hdl > synth/float16_multiplier.v
write_sdc > synth/float16_multiplier.sdc

exit
