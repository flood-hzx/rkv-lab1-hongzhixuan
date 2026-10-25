onerror {quit -code 1 -force}
if {![info exists 1]} {error "Usage: do batch.do TESTNAME SEED [RUN_ID] | do batch.do compile"}
if {$1 eq "compile"} {
    do compile.do
} else {
    if {![info exists 2]} {set 2 1}
    if {![info exists 3]} {set 3 AUTO}
    do run.do $1 $2 $3
}
quit -code 0 -force
