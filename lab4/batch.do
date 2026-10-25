# Batch macro only: errors exit nonzero; onerror stays in the do-file to avoid command-line warnings.
onerror {quit -code 1 -force}
if {![info exists 1]} {error "Usage: do batch.do TESTNAME SEED RUN_ID normal|coverage COVSET | do batch.do compile"}
if {$1 eq "compile"} {
    set lab4_run_id compile_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
    do compile.do
} else {
    if {![info exists 2]} {error "Usage: do batch.do TESTNAME SEED RUN_ID normal|coverage COVSET"}
    if {![info exists 3] || $3 eq ""} {set 3 AUTO}
    if {![info exists 4] || $4 eq ""} {set 4 normal}
    if {![info exists 5] || $5 eq ""} {set 5 final}
    do run.do $1 $2 $3 $4 $5
}
quit -code 0 -force
