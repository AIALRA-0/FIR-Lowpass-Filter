source [file join [file dirname [info script]] .. common.tcl]
source [file join [file dirname [info script]] .. vendor_fir_ip.tcl]

set top_name "fir_vendor_ip_core"
set part_name [fir_target_part]
set clk_period [fir_target_period_ns]
set build_dir [fir_build_dir $top_name]
set project_dir [file join $build_dir project]
set root [fir_repo_root]

create_project $top_name $project_dir -part $part_name -force

add_files -norecurse [concat \
    [fir_common_sources $top_name] \
    [list [file join $root rtl fir_vendor_ip_core fir_vendor_ip_core.v]] \
]
set_property include_dirs [list [fir_include_dir]] [get_filesets sources_1]

fir_create_vendor_ip fir_vendor_ip_0
update_compile_order -fileset sources_1

synth_design -top $top_name -part $part_name
create_clock -period $clk_period -name sys_clk [get_ports clk]
opt_design
place_design
phys_opt_design
route_design

fir_write_reports $top_name $build_dir
write_checkpoint -force [file join $build_dir ${top_name}.dcp]

set out_file [file join $build_dir impl_summary.txt]
set fp [open $out_file w]
puts $fp "top=$top_name"
puts $fp "part=$part_name"
puts $fp "build_dir=$build_dir"
puts $fp "target_period_ns=$clk_period"
close $fp

close_project
