# Batch macro only. Keeping onerror in this do-file gives vsim a reliable nonzero exit without a command-line warning.
onerror {quit -code 1 -force}
if {![info exists 1]} {error "Usage: do batch.do TESTNAME SEED RUN_ID | do batch.do compile"}
if {$1 eq "compile"} {
    set lab3_run_id compile_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
    do compile.do
} else {
    if {![info exists 2]} {error "Usage: do batch.do TESTNAME SEED RUN_ID"}
    if {![info exists 3] || $3 eq ""} {set 3 AUTO}
    do run.do $1 $2 $3
}
quit -code 0 -force
