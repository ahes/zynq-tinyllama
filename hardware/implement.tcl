set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware]
if {[current_project -quiet] eq ""} {open_project [file join $out llama7035_repro.xpr]}
if {[get_property DIRECTORY [current_project]] ne $out} {error "Unexpected active project"}
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {![string match {synth_design Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match {write_bitstream Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
source -notrace [file join $root hardware collect.tcl]
