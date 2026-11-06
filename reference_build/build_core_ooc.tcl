# OOC resource and compatibility check for the 128-bit single-core target.
set script_dir [file normalize [file dirname [info script]]]
set workspace  [file normalize [file join $script_dir ..]]
set src_rtl    [file join $script_dir rtl DataPath_xN.v]
set src_ip_dir [file join $workspace llama-fpga zcu104_ps_pl zcu104_vivado xci_ip]
set build_dir  [file join $script_dir build core_ooc]
set gen_rtl    [file join $build_dir DataPath_xN_7series.v]
set recreated_ip_dir [file join $build_dir recreated_ip]

file mkdir $build_dir
file mkdir $recreated_ip_dir
if {![file exists $src_rtl]} { error "Missing Zynq-7035 RTL: $src_rtl" }

# XC7Z035 has no UltraRAM.
set fd [open $src_rtl r]
set rtl_text [read $fd]
close $fd
set rtl_text [string map {"ram_style = \"ultra\"" "ram_style = \"block\""} $rtl_text]
set fd [open $gen_rtl w]
puts -nonewline $fd $rtl_text
close $fd

create_project -force llama_core_7035_ooc [file join $build_dir project] \
  -part xc7z035ffg676-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -norecurse $gen_rtl

# Recreate the reference floating-point/datamover IP in Vivado 2021.1.
foreach xci_file [glob -nocomplain [file join $src_ip_dir *.xci]] {
  set fd [open $xci_file r]
  set xci_text [read $fd]
  close $fd
  if {![regexp {"xci_name"[ ]*:[ ]*"([^"]+)"} $xci_text -> module_name]} {
    error "Cannot find xci_name in $xci_file"
  }
  if {![regexp {"component_reference"[ ]*:[ ]*"xilinx.com:ip:([^:]+):[^"]+"} $xci_text -> ip_name]} {
    error "Cannot find component_reference in $xci_file"
  }
  create_ip -name $ip_name -vendor xilinx.com -library ip \
    -module_name $module_name -dir $recreated_ip_dir
  foreach line [split $xci_text "\n"] {
    if {[regexp {^[ ]*"([^"]+)"[ ]*:[ ]*\[[ ]*\{[ ]*"value"[ ]*:[ ]*"([^"]*)".*"value_src"[ ]*:[ ]*"user"} $line -> cfg_name cfg_value]} {
      if {$cfg_name ne "Component_Name"} {
        catch {set_property CONFIG.$cfg_name $cfg_value [get_ips $module_name]}
      }
    }
  }
}
set_property generate_synth_checkpoint false [get_files -all *.xci]
generate_target all [get_ips]

synth_design -top DataPath_xN -part xc7z035ffg676-2 -mode out_of_context \
  -flatten_hierarchy none -directive RuntimeOptimized
report_utilization -hierarchical -file [file join $build_dir utilization_hier.rpt]
report_timing_summary -file [file join $build_dir timing_synth.rpt]
write_checkpoint -force [file join $build_dir DataPath_xN_xc7z035_synth.dcp]

set fd [open [file join $build_dir build_status.txt] w]
puts $fd "STATUS=SUCCESS"
puts $fd "PART=xc7z035ffg676-2"
puts $fd "TOPOLOGY=single-core"
puts $fd "AXI_DATA_WIDTH=128"
close $fd
exit
