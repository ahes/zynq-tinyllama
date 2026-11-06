# Check that the recreated design uses the captured board and no old workspace inputs.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware]
source -notrace [file join $root board ps7_config.tcl]
open_bd_design [get_files */system.bd]
set differences {}
foreach {name expected} $round55_ps7_config {
    set actual [get_property $name [get_bd_cells ps7]]
    if {$actual ne $expected} {lappend differences [list $name $expected $actual]}
}
if {[llength $differences]} {error "PS configuration differs from measured project: $differences"}
if {[get_property PART [current_project]] ne "xc7z035ffg676-2" ||
    [get_property TOP [current_fileset]] ne "system_wrapper" || [llength [get_ips]] != 36} {
    error "Part/top/IP inventory mismatch"
}
set fd [open [file join $out source_inventory.txt] w]
set tool_root [file normalize $::env(XILINX_VIVADO)]
foreach f [get_files -all] {
    set path [file normalize $f]
    puts $fd $path
    if {[string first [string tolower "$root/"] [string tolower $path]] != 0 &&
        [string first [string tolower "$tool_root/"] [string tolower $path]] != 0} {
        close $fd
        error "External workspace dependency: $path"
    }
}
close $fd
set fd [open [file join $out project_structure.json] w]
puts $fd [format {{"passed": true, "ps_config_properties_matched": %d, "ip_count": 36, "top": "system_wrapper", "part": "xc7z035ffg676-2", "no_old_workspace_source_paths": true}} [expr {[llength $round55_ps7_config]/2}]]
close $fd
puts "PROJECT_STRUCTURE_PASS PS_properties=[expr {[llength $round55_ps7_config]/2}] ips=36"
