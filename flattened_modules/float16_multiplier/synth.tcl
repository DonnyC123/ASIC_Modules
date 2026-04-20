set FREEPDK45 /vol/eecs391/FreePDK45

set_db lib_search_path [list $FREEPDK45/osu_soc/lib/files]
set_db library         [list gscl45nm.lib]


set_db hdl_search_path { . }
read_hdl [list \
    float16_decoder.v \
    leading_zero_counter.v \
    product_normalizer.v \
    product_rounder.v \
    float16_multiplier.v \
]


elaborate float16_multiplier
check_design -unresolved

set_max_delay 2.5 -from [all_inputs] -to [all_outputs]

 set_db syn_opt_effort     high
 set_db syn_generic_effort high 
 set_db syn_map_effort     high 

ungroup -all -flatten

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
