source [file join [file dirname [info script]] common.tcl]

if {![info exists ::env(TOP)] || $::env(TOP) eq ""} {
    error "Environment variable TOP must be set."
}

set top_name $::env(TOP)
set part_name [fir_target_part]
set build_dir [fir_build_dir $top_name]

create_project -in_memory -part $part_name
fir_read_sources $top_name
synth_design -top $top_name -part $part_name

if {[llength [get_ports clk]] > 0} {
    create_clock -period 5.000 -name sys_clk [get_ports clk]
}

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
close $fp

close_project

