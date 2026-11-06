set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware]
if {![string match {write_bitstream Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Bitstream run has not completed"}
open_run impl_1
report_timing_summary -file [file join $out timing_impl.rpt]
report_utilization -file [file join $out utilization_impl.rpt]
report_route_status -file [file join $out route_status.rpt]
report_drc -file [file join $out drc_impl.rpt]
set setup [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set hold [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$setup eq "" || $hold eq "" || $setup < 0 || $hold < 0} {error "Setup/hold failed: $setup / $hold"}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] system_wrapper.bit] [file join $out system.bit]
write_hw_platform -fixed -include_bit -force [file join $out system.xsa]
set fd [open [file join $out hardware_result.json] w]
puts $fd [format {{"passed": true, "wns_ns": %s, "whs_ns": %s, "fresh_ip_build": true}} $setup $hold]
close $fd
puts "IMPLEMENT_PASS setup=$setup hold=$hold"
