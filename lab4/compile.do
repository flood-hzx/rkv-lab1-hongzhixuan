# Only the four DUT modules receive code-coverage instrumentation. TB/interface/package code is not covered.
set lab4_dir [file normalize [pwd]]
set lab4_root [file normalize [file dirname $lab4_dir]]
set lab4_work [file join $lab4_dir work_lab4]
if {![info exists lab4_run_id]} {
    set lab4_run_id compile_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
}
set lab4_log_dir [file join $lab4_dir logs $lab4_run_id]
file mkdir $lab4_log_dir
if {![file exists [file join $lab4_work _info]]} {
    vlib $lab4_work
}

# The source order follows the PPA dependency chain; coverage switches apply only to DUT RTL.
vlog -sv +cover=bcesft -timescale 1ns/1ps -work $lab4_work \
    -l [file join $lab4_log_dir compile_rtl.log] \
    [file join $lab4_root lab1 apb_slave_if.sv] \
    [file join $lab4_root lab1 packet_sram.sv] \
    [file join $lab4_root lab2 packet_proc_core.sv] \
    [file join $lab4_root lab3 ppa_top.sv]
vlog -sv -timescale 1ns/1ps -work $lab4_work \
    -l [file join $lab4_log_dir compile_tb.log] \
    [file join $lab4_root lab3 ppa_if.sv] \
    [file join $lab4_root lab3 lab3_pkg.sv] \
    [file join $lab4_dir lab4_pkg.sv] \
    [file join $lab4_dir tb_lab4.sv]
