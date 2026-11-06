# Standalone project recreation. Inputs are source/configuration only.
set root [file normalize [file join [file dirname [info script]] ..]]
set hw [file join $root hardware]
set out [file join $root build hardware]
if {[file exists [file join $out llama7035_repro.xpr]]} {error "Refusing to overwrite an existing build: $out"}
if {[version -short] ne "2021.1"} {error "This reproduction requires Vivado 2021.1"}
create_project llama7035_repro $out -part xc7z035ffg676-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -norecurse [file join $root zynq7035_port rtl DataPath_xN.v]
set ip_scripts [lsort [glob [file join $hw Sources IP *.tcl]]]
if {[llength $ip_scripts] != 30} {error "Expected 30 standalone IP configuration scripts"}
foreach script $ip_scripts {source -notrace $script}
source -notrace [file join $hw Sources BD system.tcl]
if {[llength [get_files -quiet */system.bd]] != 1} {error "BD recreation failed"}
validate_bd_design
save_bd_design
generate_target all [get_files */system.bd]
set wrapper [make_wrapper -files [get_files */system.bd] -top]
add_files -norecurse $wrapper
source -notrace [file join $hw Scripts project_settings.tcl]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
source -notrace [file join $hw check_project.tcl]
write_hw_platform -fixed -force [file join $out system_preimpl.xsa]
puts "RECREATE_PASS part=xc7z035ffg676-2 top=system_wrapper ips=36"
