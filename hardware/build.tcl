set script_dir [file dirname [file normalize [info script]]]
source -notrace [file join $script_dir recreate.tcl]
source -notrace [file join $script_dir implement.tcl]
exit
