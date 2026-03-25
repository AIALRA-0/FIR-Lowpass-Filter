source [file join [file dirname [info script]] common.tcl]

set tops {
    fir_symm_base
    fir_pipe_systolic
    fir_l2_polyphase
    fir_l3_polyphase
    fir_l3_pipe
}

foreach top_name $tops {
    puts "=== Running implementation for $top_name ==="
    set ::env(TOP) $top_name
    source [file join [file dirname [info script]] synth_one.tcl]
}

