proc fir_repo_root {} {
    return [file normalize [file join [file dirname [info script]] .. ..]]
}

proc fir_target_part {} {
    if {[info exists ::env(TARGET_PART)] && $::env(TARGET_PART) ne ""} {
        return $::env(TARGET_PART)
    }
    return "xc7z020clg400-2"
}

proc fir_build_dir {top_name} {
    set root [fir_repo_root]
    set dir [file join $root build vivado $top_name]
    file mkdir $dir
    return $dir
}

proc fir_common_sources {} {
    set root [fir_repo_root]
    return [list \
        [file join $root rtl common valid_pipe.v] \
        [file join $root rtl common delay_line.v] \
        [file join $root rtl common fir_delay_signed.v] \
        [file join $root rtl common preadd_mult.v] \
        [file join $root rtl common round_sat.v] \
    ]
}

proc fir_top_source {top_name} {
    set root [fir_repo_root]
    array set top_map {
        fir_symm_base       {rtl/fir_symm_base/fir_symm_base.v}
        fir_pipe_systolic   {rtl/fir_pipe_systolic/fir_pipe_systolic.v}
        fir_l2_polyphase    {rtl/fir_l2_polyphase/fir_l2_polyphase.v}
        fir_l3_polyphase    {rtl/fir_l3_polyphase/fir_l3_polyphase.v}
        fir_l3_pipe         {rtl/fir_l3_pipe/fir_l3_pipe.v}
    }
    if {![info exists top_map($top_name)]} {
        error "Unknown top module: $top_name"
    }
    return [file join $root {*}[split $top_map($top_name) "/"]]
}

proc fir_include_dir {} {
    set root [fir_repo_root]
    return [file join $root rtl common]
}

proc fir_read_sources {top_name} {
    set srcs [concat [fir_common_sources] [list [fir_top_source $top_name]]]
    add_files -norecurse $srcs
    set_property include_dirs [list [fir_include_dir]] [current_fileset]
    update_compile_order -fileset sources_1
}

proc fir_write_reports {top_name report_dir} {
    report_utilization -hierarchical -file [file join $report_dir utilization_hier.rpt]
    report_utilization -file [file join $report_dir utilization.rpt]
    report_timing_summary -delay_type max -max_paths 10 -file [file join $report_dir timing_summary.rpt]
    report_power -file [file join $report_dir power.rpt]
    report_drc -file [file join $report_dir drc.rpt]
}
