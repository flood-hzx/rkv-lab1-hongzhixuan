# 从 try/lab1 执行；RTL 自包含，TB 内先定义类型/interface，再定义使用它们的顶层。
# _info 只判断工作库是否建立，不跳过编译；每次都用本目录源码更新可执行设计。
set week1_dir [file normalize [pwd]]
set week1_work [file join $week1_dir work_week1]
if {![info exists week1_log_dir]} {
    set week1_log_dir [file join $week1_dir logs compile_[clock clicks]]
}
file mkdir $week1_log_dir
if {![file exists [file join $week1_work _info]]} {
    vlib $week1_work
}
vlog -sv -timescale 1ns/1ps -work $week1_work \
    -l [file join $week1_log_dir compile.log] \
    [file join $week1_dir apb_slave_if.sv] \
    [file join $week1_dir packet_sram.sv] \
    [file join $week1_dir tb_lab1.sv]
