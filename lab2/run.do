# GUI entry: do run.do TESTNAME SEED [RUN_ID]. Start in the Lab2 directory.
set lab2_base [file normalize [pwd]]
set lab2_test normal
set lab2_seed 1
set lab2_id [format "%s_%s_%s" [clock format [clock seconds] -format %Y%m%d_%H%M%S] [pid] [clock clicks -microseconds]]
if {[info exists 1]} {set lab2_test $1}
if {[info exists 2]} {set lab2_seed $2}
if {[info exists 3] && $3 ne "" && $3 ne "AUTO"} {set lab2_id $3}
if {$lab2_test ni {normal length timing type checksum extension}} {
    error "Unknown TESTNAME=$lab2_test; use normal/length/timing/type/checksum/extension"
}
if {![string is integer -strict $lab2_seed] || $lab2_seed < 1} {
    error "SEED must be a positive integer"
}
if {![regexp {^[A-Za-z0-9_-]+$} $lab2_id]} {error "Invalid RUN_ID"}
set lab2_case [format "%s_%s" $lab2_test $lab2_seed]
set lab2_log_dir [file join $lab2_base logs $lab2_id $lab2_case]
set lab2_wave [file join $lab2_base waves $lab2_id $lab2_case.wlf]
if {[file exists $lab2_log_dir] || [file exists $lab2_wave]} {
    error "Results already exist: RUN_ID=$lab2_id TESTNAME=$lab2_test SEED=$lab2_seed"
}
file mkdir $lab2_log_dir
file mkdir [file dirname $lab2_wave]
quit -sim
do [file join $lab2_base compile.do]
vsim -lib $lab2_work -voptargs=+acc -sv_seed $lab2_seed \
    -l [file join $lab2_log_dir run.log] \
    -wlf $lab2_wave \
    tb_lab2 +TESTNAME=$lab2_test +SEED=$lab2_seed
onfinish stop
log -r /tb_lab2/*
if {![batch_mode]} {do [file join $lab2_base wave.do]}
run -all
# A normal finish and a fatal error both stop simulation; require the TB success flag.
if {[examine -radix binary /tb_lab2/test_done] ne "1"} {
    error "LAB2_FAILED test=$lab2_test seed=$lab2_seed; inspect the transcript"
}
puts "LAB2_OK test=$lab2_test seed=$lab2_seed run_id=$lab2_id"
