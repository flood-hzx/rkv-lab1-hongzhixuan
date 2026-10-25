# GUI entry: do run.do TESTNAME SEED RUN_ID coverage|normal COVSET. Start in try/lab4.
set lab4_dir [file normalize [pwd]]
if {![info exists 1]} {set 1 smoke}
if {![info exists 2]} {set 2 1}
if {![info exists 3] || $3 eq "" || $3 eq "AUTO"} {
    set lab4_run_id [clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
} else {
    set lab4_run_id $3
}
set lab4_test $1
set lab4_seed $2
set lab4_coverage 0
set lab4_covset final
if {[info exists 4] && $4 ne ""} {
    if {$4 ni {normal coverage}} {error "Run mode must be normal or coverage"}
    if {$4 eq "coverage"} {set lab4_coverage 1}
}
if {[info exists 5] && $5 ne ""} {set lab4_covset $5}
if {![regexp {^[A-Za-z0-9_.-]+$} $lab4_test]} {error "Invalid TESTNAME '$lab4_test'"}
if {![regexp {^[A-Za-z0-9_.-]+$} $lab4_run_id]} {error "Invalid RUN_ID '$lab4_run_id'"}
if {$lab4_covset ni {baseline final}} {error "COVSET must be baseline or final"}
if {![string is integer -strict $lab4_seed] || $lab4_seed < 1} {error "SEED must be a positive integer"}

set lab4_log_dir [file join $lab4_dir logs $lab4_run_id]
set lab4_wave_dir [file join $lab4_dir waves $lab4_run_id]
set lab4_cov_dir [file join $lab4_dir coverage $lab4_covset ${lab4_test}_${lab4_seed}_${lab4_run_id}]
foreach output_dir [list $lab4_log_dir $lab4_wave_dir] {
    if {[file exists $output_dir]} {error "Refusing to overwrite existing run output: $output_dir"}
}
if {$lab4_coverage && [file exists $lab4_cov_dir]} {error "Refusing to overwrite existing coverage output: $lab4_cov_dir"}
file mkdir $lab4_log_dir
file mkdir $lab4_wave_dir
if {$lab4_coverage} {file mkdir $lab4_cov_dir}

quit -sim
set lab4_compile_dir $lab4_run_id
do [file join $lab4_dir compile.do]
set lab4_work [file join $lab4_dir work_lab4]
set lab4_wlf [file join $lab4_wave_dir ${lab4_test}_${lab4_seed}.wlf]
set lab4_ucdb [file join $lab4_cov_dir ${lab4_test}_${lab4_seed}.ucdb]
if {$lab4_coverage} {
    vsim -coverage -lib $lab4_work -voptargs=+acc -fsmdebug -sv_seed $lab4_seed \
        -l [file join $lab4_log_dir ${lab4_test}_${lab4_seed}.log] \
        -wlf $lab4_wlf tb_lab4 +TESTNAME=$lab4_test +SEED=$lab4_seed
} else {
    vsim -lib $lab4_work -voptargs=+acc -fsmdebug -sv_seed $lab4_seed \
        -l [file join $lab4_log_dir ${lab4_test}_${lab4_seed}.log] \
        -wlf $lab4_wlf tb_lab4 +TESTNAME=$lab4_test +SEED=$lab4_seed
}
log -r /*
onfinish stop
if {![batch_mode]} {do [file join $lab4_dir wave.do]}
run -all
set lab4_done [examine -radix unsigned /tb_lab4/test_done]
if {$lab4_done != 1} {error "FAIL test=$lab4_test seed=$lab4_seed: test_done=$lab4_done (missing PASS completion)"}
if {$lab4_coverage} {
    coverage save -codeAll -cvg -testname ${lab4_test}_seed${lab4_seed} $lab4_ucdb
    if {![file exists $lab4_ucdb]} {error "Coverage save did not create $lab4_ucdb"}
}
puts "LAB4_PASS test=$lab4_test seed=$lab4_seed run_id=$lab4_run_id coverage=$lab4_coverage covset=$lab4_covset"
