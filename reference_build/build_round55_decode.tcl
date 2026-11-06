set script_dir [file normalize [file dirname [info script]]]
set artifact_dir [file join $script_dir build round55_dialogue_diagnosis_20261101]
set rtl_path [file join $script_dir rtl DataPath_xN.v]
foreach {name marker} {
    penalty_exhaustive_pass.log {REPETITION_PENALTY_EXHAUSTIVE_PASS count=65536}
    sampler_full_pass.log {SAMPLER_POLICY_PASS vocab=32000 rows=12}
    sampler_window_eviction_pass.log {SAMPLER_POLICY_PASS vocab=64 rows=140}
} {
    set handle [open [file join $artifact_dir $name] r]
    set text [read $handle]
    close $handle
    if {[string first $marker $text] < 0 || [regexp {Fatal:|Error:} $text]} {
        error "Round55 required simulation failed: $name"
    }
}
set handle [open $rtl_path r]
set text [read $handle]
close $handle
foreach marker {
    {assign addLogic_residual = (scaleResidual ?}
    {assign clk_0_resetn = (S00_ARESETN && (! cfg_resetOut));}
    {candidate_payload}
    {historyCommit_payload}
} {
    if {[string first $marker $text] < 0} {error "Missing Round55 RTL feature: $marker"}
}
file copy -force $rtl_path [file join $artifact_dir DataPath_xN_round55.v]
open_project [file join $script_dir build full_system project llama_zynq7035_full.xpr]
if {[get_property PART [current_project]] ne "xc7z035ffg676-2"} {error "Unexpected part"}
puts "ROUND55_PROJECT_READY"
