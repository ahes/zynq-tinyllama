# Build the MLK-F29-CZ10 XC7Z035 PS-only TinyLlama system.
set script_dir [file normalize [file dirname [info script]]]
set workspace  [file normalize [file join $script_dir ..]]
set build_dir  [file join $script_dir build full_system]
set rtl_file   [file join $script_dir rtl DataPath_xN.v]
set preset_matches [glob -nocomplain [file join $workspace 7035* 01_start_soc soc_prj uisrc 06_doc MLK_F29_7035.tcl]]
if {[llength $preset_matches] != 1} { error "Expected one MLK_F29_7035.tcl preset, found $preset_matches" }
set preset [lindex $preset_matches 0]
set ip_dir     [file join $script_dir build core_ooc recreated_ip]

foreach f [list $rtl_file $preset] {
  if {![file exists $f]} { error "Required input missing: $f" }
}
file mkdir $build_dir
create_project -force llama_zynq7035_full [file join $build_dir project] \
  -part xc7z035ffg676-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -norecurse $rtl_file
foreach xci [glob -nocomplain [file join $ip_dir * *.xci]] {
  add_files -norecurse $xci
}

source $preset
create_bd_design system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [apply_preset ps7] [get_bd_cells ps7]
set_property -dict [list \
  CONFIG.PCW_USE_M_AXI_GP0 {1} \
  CONFIG.PCW_USE_S_AXI_HP0 {1} \
  CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
  CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
  CONFIG.PCW_EN_CLK0_PORT {1} \
  CONFIG.PCW_EN_RST0_PORT {1} \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
] [get_bd_cells ps7]
make_bd_intf_pins_external [get_bd_intf_pins ps7/DDR]
make_bd_intf_pins_external [get_bd_intf_pins ps7/FIXED_IO]
set_property name DDR [get_bd_intf_ports DDR_0]
set_property name FIXED_IO [get_bd_intf_ports FIXED_IO_0]

create_bd_cell -type module -reference DataPath_xN llama_core
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI:S00_AXIL} [get_bd_pins llama_core/S00_ACLK]
set_property CONFIG.ASSOCIATED_RESET {S00_ARESETN} [get_bd_pins llama_core/S00_ACLK]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100m
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
  [get_bd_pins rst_100m/slowest_sync_clk] \
  [get_bd_pins llama_core/S00_ACLK]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_100m/ext_reset_in]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins llama_core/S00_ARESETN]

# GP0 AXI3 -> accelerator AXI4-Lite control.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axil_protocol
set_property -dict [list CONFIG.SI_PROTOCOL {AXI3} CONFIG.MI_PROTOCOL {AXI4LITE}] \
  [get_bd_cells axil_protocol]
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axil_protocol/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axil_protocol/M_AXI] [get_bd_intf_pins llama_core/S00_AXIL]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
  [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins axil_protocol/aclk]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axil_protocol/aresetn]

# Accelerator AXI4 128-bit -> PS HP0 AXI3 64-bit, all at FCLK0=100 MHz.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 hp0_dwidth
set_property -dict [list CONFIG.SI_DATA_WIDTH {128} CONFIG.MI_DATA_WIDTH {64}] [get_bd_cells hp0_dwidth]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 hp0_protocol
set_property -dict [list CONFIG.SI_PROTOCOL {AXI4} CONFIG.MI_PROTOCOL {AXI3}] [get_bd_cells hp0_protocol]
connect_bd_intf_net [get_bd_intf_pins llama_core/M00_AXI] [get_bd_intf_pins hp0_dwidth/S_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_dwidth/M_AXI] [get_bd_intf_pins hp0_protocol/S_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_protocol/M_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
  [get_bd_pins hp0_dwidth/s_axi_aclk] [get_bd_pins hp0_protocol/aclk] \
  [get_bd_pins ps7/S_AXI_HP0_ACLK]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] \
  [get_bd_pins hp0_dwidth/s_axi_aresetn] [get_bd_pins hp0_protocol/aresetn]

assign_bd_address -offset 0x43C00000 -range 64K \
  -target_address_space [get_bd_addr_spaces ps7/Data] \
  [get_bd_addr_segs llama_core/S00_AXIL/reg0]
assign_bd_address
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
set wrapper [make_wrapper -files [get_files system.bd] -top]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
write_hw_platform -fixed -force [file join $build_dir llama_zynq7035_full.xsa]
puts "CREATE_FULL_SYSTEM=SUCCESS"
exit
