# Merge only one named coverage set; preserve raw data and report both raw and filtered copies.
onerror {quit -code 1 -force}
set lab4_dir [file normalize [pwd]]
set lab4_cov_root [file join $lab4_dir coverage]
if {![info exists 1] || $1 eq ""} {set lab4_covset final} else {set lab4_covset $1}
if {$lab4_covset ni {baseline final}} {error "COVSET must be baseline or final"}
if {![info exists 2] || $2 eq "" || $2 eq "AUTO"} {
    set lab4_merge_id [clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]_[clock clicks -microseconds]
} else {
    set lab4_merge_id $2
}
if {![regexp {^[A-Za-z0-9_.-]+$} $lab4_merge_id]} {error "Invalid MERGE_ID '$lab4_merge_id'"}
set lab4_set_dir [file join $lab4_cov_root $lab4_covset]
set lab4_merged_dir [file join $lab4_cov_root merged_${lab4_covset}_${lab4_merge_id}]
set lab4_report_dir [file join $lab4_dir reports $lab4_covset $lab4_merge_id]
if {[file exists $lab4_merged_dir] || [file exists $lab4_report_dir]} {
    error "Refusing to overwrite existing merge/report output for COVSET=$lab4_covset MERGE_ID=$lab4_merge_id"
}
if {![file isdirectory $lab4_set_dir]} {error "No UCDB set directory $lab4_set_dir; run make cov COVSET=$lab4_covset first"}

# Inputs must match the per-run folder and filename convention. This excludes merged outputs and other sets.
set lab4_inputs {}
foreach run_dir [lsort [glob -nocomplain -types d -directory $lab4_set_dir *]] {
    set run_folder [file tail $run_dir]
    if {![regexp {^.+_[0-9]+_.+$} $run_folder]} {continue}
    foreach db [glob -nocomplain -types f -directory $run_dir *.ucdb] {
        if {[regexp {^.+_[0-9]+\.ucdb$} [file tail $db]]} {lappend lab4_inputs $db}
    }
}
set lab4_inputs [lsort -unique $lab4_inputs]
if {[llength $lab4_inputs] == 0} {error "No per-run UCDBs for COVSET=$lab4_covset under $lab4_set_dir"}
file mkdir $lab4_merged_dir
file mkdir $lab4_report_dir
set lab4_raw_ucdb [file join $lab4_merged_dir merged_raw.ucdb]
set lab4_filter_work_ucdb [file join $lab4_merged_dir exclusion_working_copy.ucdb]
set lab4_filtered_ucdb [file join $lab4_merged_dir merged_filtered.ucdb]
puts "Merging [llength $lab4_inputs] $lab4_covset UCDB files into $lab4_raw_ucdb"
exec vcover merge -out $lab4_raw_ucdb {*}$lab4_inputs
if {![file exists $lab4_raw_ucdb]} {error "Raw merged UCDB was not created"}

# Some Questa viewcov workflows can persist exclusions to the opened UCDB. Filter a physical copy so raw stays immutable.
file copy $lab4_raw_ucdb $lab4_filter_work_ucdb
puts "Applying exclusions to copied dataset $lab4_filter_work_ucdb and saving $lab4_filtered_ucdb"
coverage open $lab4_filter_work_ucdb lab4_filter_work
# Apply the project exclusion script in this same Questa session after the copy becomes active.
do [file join $lab4_dir exclusions.do]
coverage save -codeAll -cvg $lab4_filtered_ucdb
if {![file exists $lab4_filtered_ucdb]} {error "Filtered UCDB was not created"}

# Keep each code metric separate: statement is the Questa line-coverage equivalent.
set lab4_categories [list [list line s] [list branch b] [list condition c] [list fsm f] [list toggle t]]
set lab4_dus {apb_slave_if packet_sram packet_proc_core ppa_top}
foreach dataset [list [list raw $lab4_raw_ucdb] [list filtered $lab4_filtered_ucdb]] {
    set dataset_name [lindex $dataset 0]
    set db_path [lindex $dataset 1]
    set dataset_dir [file join $lab4_report_dir $dataset_name]
    file mkdir [file join $dataset_dir text overall]
    file mkdir [file join $dataset_dir html]

    # Functional coverage is independently reported with coverpoint/bin details.
    exec vcover report -cvg -details -output [file join $dataset_dir text overall functional_bins.txt] $db_path
    exec vcover report -cvg -details -html -output [file join $dataset_dir html functional] $db_path

    # Global totals combine only instrumented DUT RTL; emit one metric per report, never a cross-category average.
    foreach category $lab4_categories {
        set category_name [lindex $category 0]
        set category_code [lindex $category 1]
        exec vcover report -code $category_code -summary -output [file join $dataset_dir text overall ${category_name}_summary.txt] $db_path
        exec vcover report -code $category_code -html -output [file join $dataset_dir html $category_name] $db_path
    }

    # Per-DUT details retain the location of every hit/miss while keeping the five metrics separate.
    foreach du $lab4_dus {
        set du_text_dir [file join $dataset_dir text $du]
        file mkdir $du_text_dir
        foreach category $lab4_categories {
            set category_name [lindex $category 0]
            set category_code [lindex $category 1]
            exec vcover report -code $category_code -du=$du -details -output [file join $du_text_dir ${category_name}.txt] $db_path
        }
    }
}
puts "Coverage COVSET=$lab4_covset runs=[llength $lab4_inputs] raw=$lab4_raw_ucdb filtered=$lab4_filtered_ucdb reports=$lab4_report_dir"
quit -code 0 -force
