set script_dir [file normalize [file dirname [info script]]]
set build_dir [file join $script_dir build full_system]
open_project [file join $build_dir project llama_zynq7035_full.xpr]
set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "synth_design Complete*" $synth_status]} {
  launch_runs synth_1 -jobs 2
  wait_on_run synth_1
  set synth_status [get_property STATUS [get_runs synth_1]]
}
if {![string match "synth_design Complete*" $synth_status]} {
  error "Synthesis failed: $synth_status"
}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {![string match "write_bitstream Complete*" $impl_status]} {
  error "Implementation failed: $impl_status"
}
open_run impl_1
report_utilization -file [file join $build_dir utilization_impl.rpt]
report_timing_summary -file [file join $build_dir timing_impl.rpt]
report_route_status -file [file join $build_dir route_status.rpt]
report_drc -file [file join $build_dir drc_impl.rpt]
write_checkpoint -force [file join $build_dir llama_zynq7035_full_impl.dcp]
write_bitstream -force [file join $build_dir llama_zynq7035_full.bit]
write_hw_platform -fixed -include_bit -force [file join $build_dir llama_zynq7035_full_with_bit.xsa]
puts "BUILD_FULL_SYSTEM=SUCCESS"
exit
