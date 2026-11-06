# XSCT 2021.1: fresh platform, BSP, application and FSBL from this tree's XSA.
set root [file normalize [file join [file dirname [info script]] ..]]
set xsa [file join $root build hardware system.xsa]
if {[llength $argv] > 0} {set xsa [file normalize [lindex $argv 0]]}
if {![file isfile $xsa]} {error "Missing locally built XSA: $xsa"}
set ws [file join $root build vitis]
setws $ws
platform create -name llama7035_repro -hw $xsa -proc ps7_cortexa9_0 -os standalone
platform write
platform active llama7035_repro
domain active standalone_domain
bsp setlib -name xilffs
bsp regenerate
platform generate
set sources [file join $root build ps_sources]
file mkdir $sources
file copy -force [file join $root zynq7035_port software round55 main.c] [file join $sources main.c]
file copy -force [file join $root zynq7035_port software lscript.ld] [file join $sources lscript.ld]
app create -name llama7035_app -platform llama7035_repro -domain standalone_domain -template {Empty Application(C)}
importsources -name llama7035_app -path $sources
app config -name llama7035_app define-compiler-symbols ZYNQ7035
app config -name llama7035_app define-compiler-symbols MAX_DECODE_TOKENS=128
app config -name llama7035_app compiler-misc {-Wall -Wextra -Werror}
app build -name llama7035_app
app create -name llama7035_fsbl -platform llama7035_repro -domain standalone_domain -template {Zynq FSBL}
app build -name llama7035_fsbl
puts "SOFTWARE_BUILD_PASS fresh_bsp=true fresh_fsbl=true"
exit
