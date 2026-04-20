# tclsh sim.tcl        # batch
# tclsh sim.tcl gui    # gui

set TOP float16_multiplier_tb

set RTL {
    float16_decoder.v
    leading_zero_counter.v
    product_normalizer.v
    product_rounder.v
    float16_multiplier.v
}

set TB {
    float16_multiplier_tb.v
}

set FLAGS {-64bit -sv -timescale 1ns/1ps -access +rwc}

set MODE [expr {[llength $argv] > 0 ? [lindex $argv 0] : "batch"}]

if {$MODE eq "gui"} {
    set CMD "xrun $FLAGS $RTL $TB -top $TOP -gui"
} else {
    set CMD "xrun $FLAGS $RTL $TB -top $TOP -input run.tcl -l xrun.log"
}

puts $CMD
exec {*}[split $CMD] >@stdout 2>@stderr
