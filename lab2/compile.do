set lab2_dir [file normalize [pwd]]
set lab2_work [file join $lab2_dir work_lab2]
if {![info exists lab2_log_dir]} {
    set lab2_log_dir [file join $lab2_dir logs compile_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]]
}
file mkdir $lab2_log_dir
if {![file exists [file join $lab2_work _info]]} {vlib $lab2_work}
# 类包使用 virtual proc_if，所以 interface 必须先于 package 编译。
vlog -sv -timescale 1ns/1ps -work $lab2_work \
    -l [file join $lab2_log_dir compile.log] \
    [file join $lab2_dir proc_if.sv] \
    [file join $lab2_dir lab2_pkg.sv] \
    [file join $lab2_dir packet_proc_core.sv] \
    [file join $lab2_dir tb_lab2.sv]
