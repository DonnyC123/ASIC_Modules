# =============================================================================
# Common Genus Synthesis Script
# =============================================================================
# Variables expected to be set by design.tcl before sourcing:
#
#   DESIGN_NAME    - top-level module name (e.g. srt_sqrt)
#   REPO_ROOT      - absolute path to repo root
#   RUN_F          - absolute path to sim run.f  (TB files auto-filtered)
#   WORK_DIR       - output directory for reports/netlist (created if absent)
#
# Optional (have defaults):
#   CLK_PORT       - clock port name        (default: clk)
#   CLK_PERIOD_NS  - target period in ns    (default: 2.0 = 500 MHz)
#   TECH_LIB       - Liberty file path      (default: $env(TECH_LIB))
#   TB_EXCLUDE     - extra glob patterns to filter from run.f (default: {})
# =============================================================================

# --- Defaults ----------------------------------------------------------------
if {![info exists CLK_PORT]}      { set CLK_PORT      "clk" }
if {![info exists CLK_PERIOD_NS]} { set CLK_PERIOD_NS  2.0  }
if {![info exists TB_EXCLUDE]}    { set TB_EXCLUDE     {}   }

if {![info exists TECH_LIB]} {
    if {[info exists env(TECH_LIB)]} {
        set TECH_LIB $env(TECH_LIB)
    } else {
        puts "\nERROR: TECH_LIB not set."
        puts "  Set it in design.tcl:  set TECH_LIB /path/to/lib.lib"
        puts "  or as env var:         setenv TECH_LIB /path/to/lib.lib\n"
        exit 1
    }
}

file mkdir $WORK_DIR

# --- Helpers -----------------------------------------------------------------
proc log_section {title} {
    puts "\n[string repeat = 60]"
    puts "  $title"
    puts "[string repeat = 60]\n"
}

# Read a sim run.f, resolve every path relative to the run.f directory,
# and return a list of absolute file paths with TB files removed.
#
# A file is considered a TB file if its resolved path contains any of:
#   /tb/   _tb.   _tb_   tb_pkg
# Extra patterns can be passed via $extra_exclude (list of glob strings
# matched against the full path).
proc read_rtl_from_runf {runf_path {extra_exclude {}}} {
    set runf_dir [file dirname [file normalize $runf_path]]
    set fh [open $runf_path r]
    set rtl_files {}

    while {[gets $fh line] >= 0} {
        set line [string trim $line]

        # Skip blank lines and comments (// or #)
        if {$line eq ""}                      continue
        if {[string match "//*" $line]}       continue
        if {[string match "#*"  $line]}       continue

        # Resolve relative to the run.f directory
        set abs [file normalize [file join $runf_dir $line]]

        # Built-in TB filters
        set skip 0
        foreach pat {
            "*/tb/*"
            "*_tb.sv"
            "*_tb_*"
            "*tb_pkg*"
        } {
            if {[string match $pat $abs]} { set skip 1; break }
        }

        # Extra user-supplied filters
        if {!$skip} {
            foreach pat $extra_exclude {
                if {[string match $pat $abs]} { set skip 1; break }
            }
        }

        if {$skip} {
            puts "  \[filtered\] skipping TB file: [file tail $abs]"
        } elseif {$abs ni $rtl_files} {
            lappend rtl_files $abs
        }
    }
    close $fh
    return $rtl_files
}

# =============================================================================
# 1. Technology Library
# =============================================================================
log_section "Reading Technology Library"

set_db init_lib_search_path [file dirname $TECH_LIB]
read_libs $TECH_LIB

# =============================================================================
# 2. Read RTL  (filtered from run.f)
# =============================================================================
log_section "Reading RTL from $RUN_F"

set rtl_files [read_rtl_from_runf $RUN_F $TB_EXCLUDE]
puts "  Files to elaborate:"
foreach f $rtl_files { puts "    $f" }
puts ""

read_hdl -sv {*}$rtl_files

# =============================================================================
# 3. Elaborate
# =============================================================================
log_section "Elaborating $DESIGN_NAME"

elaborate $DESIGN_NAME
check_design -unresolved

# =============================================================================
# 4. Timing Constraints
# =============================================================================
log_section "Applying Constraints  (period = ${CLK_PERIOD_NS} ns  /  [expr {1000.0/$CLK_PERIOD_NS}] MHz)"

create_clock -name clk -period $CLK_PERIOD_NS [get_db [get_ports $CLK_PORT]]

set io_delay [expr {$CLK_PERIOD_NS * 0.1}]
set_input_delay  -clock clk $io_delay \
    [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]
set_output_delay -clock clk $io_delay [all_outputs]

set_load        0.05 [all_outputs]
set_drive       0    [get_ports $CLK_PORT]
set_max_fanout  20   [current_design]

# =============================================================================
# 5. Synthesis
# =============================================================================
log_section "Synthesis - Generic"
set_db syn_generic_effort medium
syn_generic

log_section "Synthesis - Mapping"
set_db syn_map_effort medium
syn_map

log_section "Synthesis - Optimization"
set_db syn_opt_effort medium
syn_opt

# =============================================================================
# 6. Reports
# =============================================================================
log_section "Writing Reports  ->  $WORK_DIR"

report_timing -num_paths 10 > $WORK_DIR/timing.rpt
report_area                 > $WORK_DIR/area.rpt
report_gates                > $WORK_DIR/gates.rpt
report_power  -hierarchy    > $WORK_DIR/power.rpt
report_qor                  > $WORK_DIR/qor.rpt

report_qor
report_timing -num_paths 5

# =============================================================================
# 7. Write Outputs
# =============================================================================
log_section "Writing Netlist and SDC"

write_hdl > $WORK_DIR/${DESIGN_NAME}_netlist.v
write_sdc > $WORK_DIR/${DESIGN_NAME}.sdc

puts "\n[string repeat = 60]"
puts "  Done.  Results in: $WORK_DIR"
puts "[string repeat = 60]\n"
