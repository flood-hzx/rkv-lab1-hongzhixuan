# GUI entry: do run.do TESTNAME SEED [RUN_ID]. Start in try/lab3.
set lab3_dir [file normalize [pwd]]
if {![info exists 1]} {set 1 smoke}
if {![info exists 2]} {set 2 1}
if {![info exists 3] || $3 eq "" || $3 eq "AUTO"} {
    set lab3_run_id [clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
} else {
    set lab3_run_id $3
}
set lab3_test $1
set lab3_seed $2
if {![regexp {^[A-Za-z0-9_.-]+$} $lab3_test]} {error "Invalid TESTNAME '$lab3_test'"}
if {![regexp {^[A-Za-z0-9_.-]+$} $lab3_run_id]} {error "Invalid RUN_ID '$lab3_run_id'"}
if {![string is integer -strict $lab3_seed] || $lab3_seed < 1} {error "SEED must be a positive integer"}

set lab3_log_dir [file join $lab3_dir logs $lab3_run_id]
set lab3_wave_dir [file join $lab3_dir waves $lab3_run_id]
foreach output_dir [list $lab3_log_dir $lab3_wave_dir] {
    if {[file exists $output_dir]} {error "Refusing to overwrite existing run output: $output_dir"}
}
file mkdir $lab3_log_dir
file mkdir $lab3_wave_dir

quit -sim
set lab3_compile_dir $lab3_run_id
do [file join $lab3_dir compile.do]
set lab3_work [file join $lab3_dir work_lab3]
vsim -lib $lab3_work -voptargs=+acc -fsmdebug -sv_seed $lab3_seed \
    -l [file join $lab3_log_dir ${lab3_test}_${lab3_seed}.log] \
    -wlf [file join $lab3_wave_dir ${lab3_test}_${lab3_seed}.wlf] \
    tb_lab3 +TESTNAME=$lab3_test +SEED=$lab3_seed
log -r /*
onfinish stop
if {![batch_mode]} {do [file join $lab3_dir wave.do]}
run -all
set lab3_done [examine -radix unsigned /tb_lab3/test_done]
if {$lab3_done != 1} {error "FAIL test=$lab3_test seed=$lab3_seed: test_done=$lab3_done (missing PASS completion)"}
puts "LAB3_PASS test=$lab3_test seed=$lab3_seed run_id=$lab3_run_id"
