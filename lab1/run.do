# GUI：先 cd 到 try/lab1，再 do run.do smoke 1。
set week1_base [file normalize [pwd]]
set week1_test smoke
set week1_seed 1
set week1_id [format "%s_%s" [clock format [clock seconds] -format %Y%m%d_%H%M%S] [clock clicks]]
if {[info exists 1]} {set week1_test $1}
if {[info exists 2]} {set week1_seed $2}
if {[info exists 3]} {set week1_id $3}
if {$week1_test ni {smoke regress defaults control memory results patterns errors irq irq_cycle}} {
    error "TEST must be smoke/regress/defaults/control/memory/results/patterns/errors/irq/irq_cycle"
}
if {![string is integer -strict $week1_seed] || $week1_seed < 1} {
    error "SEED must be a positive integer"
}
if {![regexp {^[A-Za-z0-9_-]+$} $week1_id]} {error "Invalid RUN_ID"}
set week1_log_dir [file join $week1_base logs $week1_id ${week1_test}_${week1_seed}]
set week1_wave [file join $week1_base waves $week1_id ${week1_test}_${week1_seed}.wlf]
if {[file exists $week1_log_dir] || [file exists $week1_wave]} {
    error "Results already exist: RUN_ID=$week1_id TEST=$week1_test SEED=$week1_seed"
}
file mkdir $week1_log_dir
file mkdir [file dirname $week1_wave]
quit -sim
do [file join $week1_base compile.do]
# -sv_seed 控制随机流；同值 +SEED 仅用于 TB 记录，不再次设置随机数发生器。
vsim -lib $week1_work -voptargs=+acc -sv_seed $week1_seed \
    -l [file join $week1_log_dir run.log] \
    -wlf $week1_wave \
    tb_lab1 +TEST=$week1_test +SEED=$week1_seed
onfinish stop
log -r /tb_lab1/*
if {![batch_mode]} {
    do [file join $week1_base wave.do]
}
run -all
# $fatal 和正常 $finish 都可能让仿真停下；只有最终检查完成的标志为 1 才成功。
# 二进制读取避免单比特被工具按有符号十进制显示为 -1。
if {[examine -radix binary /tb_lab1/test_done] ne "1"} {
    error "Week1 failed: inspect the transcript"
}
puts "WEEK1_OK test=$week1_test seed=$week1_seed"
