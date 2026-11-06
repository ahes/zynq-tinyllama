set script_dir [file normalize [file dirname [info script]]]
set artifact_dir [file join $script_dir build round55_dialogue_diagnosis_20261101]
if {![string match "write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Round55 implementation has not completed"
}
open_run impl_1
report_utilization -file [file join $artifact_dir utilization_impl.rpt]
report_timing_summary -file [file join $artifact_dir timing_impl.rpt]
report_route_status -file [file join $artifact_dir route_status.rpt]
report_drc -file [file join $artifact_dir drc_impl.rpt]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$wns eq "" || $whs eq "" || $wns < 0 || $whs < 0} {error "Round55 setup/hold timing failed"}
set handle [open [file join $artifact_dir hardware_timing.json] w]
puts $handle [format {{"wns_ns": %s, "whs_ns": %s}} $wns $whs]
close $handle
write_checkpoint -force [file join $artifact_dir llama_zynq7035_round55_impl.dcp]
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] system_wrapper.bit] [file join $artifact_dir llama_zynq7035_round55.bit]
write_hw_platform -fixed -include_bit -force [file join $artifact_dir llama_zynq7035_round55.xsa]
puts "ROUND55_BUILD=SUCCESS"
