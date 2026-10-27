# Called from try/lab3 by Makefile or run.do. Only the project RTL/TB list is compiled.
set lab3_dir [file normalize [pwd]]
set lab3_root [file normalize [file dirname $lab3_dir]]
set lab3_work [file join $lab3_dir work_lab3]
if {![info exists lab3_run_id]} {
    set lab3_run_id compile_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
    file mkdir [file join $lab3_dir logs $lab3_run_id]
}
set lab3_log_dir [file join $lab3_dir logs $lab3_run_id]
file mkdir $lab3_log_dir
if {![file exists [file join $lab3_work _info]]} {
    vlib $lab3_work
}

vlog -sv -timescale 1ns/1ps -work $lab3_work \
    -l [file join $lab3_log_dir compile.log] \
    [file join $lab3_root lab1 apb_slave_if.sv] \
    [file join $lab3_root lab1 packet_sram.sv] \
    [file join $lab3_root lab2 packet_proc_core.sv] \
    [file join $lab3_dir ppa_top.sv] \
    [file join $lab3_dir ppa_if.sv] \
    [file join $lab3_dir lab3_pkg.sv] \
    [file join $lab3_dir tb_lab3.sv]
