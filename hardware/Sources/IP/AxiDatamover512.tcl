##################################################################
# CHECK VIVADO VERSION
##################################################################

set scripts_vivado_version 2021.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
  catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an updated script."}
  return 1
}

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source AxiDatamover512.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./ip_export/ip_export.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  create_project ip_export ip_export -part xc7z035ffg676-2
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:axi_datamover:5.1 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP AxiDatamover512
##################################################################

set AxiDatamover512 [create_ip -name axi_datamover -vendor xilinx.com -library ip -version 5.1 -module_name AxiDatamover512]

set_property -dict { 
  CONFIG.c_m_axi_mm2s_data_width {512}
  CONFIG.c_m_axis_mm2s_tdata_width {512}
  CONFIG.c_mm2s_burst_size {64}
  CONFIG.c_mm2s_btt_used {23}
  CONFIG.c_m_axi_s2mm_data_width {512}
  CONFIG.c_s_axis_s2mm_tdata_width {512}
  CONFIG.c_s2mm_burst_size {64}
  CONFIG.c_s2mm_btt_used {23}
} [get_ips AxiDatamover512]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $AxiDatamover512

##################################################################

