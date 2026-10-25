# 批处理失败返回 1，正常结束返回 0；GUI 使用 run.do，不使用此脚本。
onerror {quit -code 1 -force}
if {![info exists 1]} {error "Usage: do batch.do TEST SEED"}
if {$1 eq "compile"} {
    do compile.do
} else {
    if {![info exists 2]} {set 2 1}
    if {![info exists 3]} {
        do run.do $1 $2
    } else {
        do run.do $1 $2 $3
    }
}
quit -code 0 -force
