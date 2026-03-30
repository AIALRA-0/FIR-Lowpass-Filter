proc fir_vendor_coeff_vector {} {
    set root [fir_repo_root]
    set coeff_path [file join $root coeffs final_fixed_q20_full.memh]
    if {![file exists $coeff_path]} {
        error "Vendor FIR coefficient file not found: $coeff_path"
    }

    set fp [open $coeff_path r]
    set raw_text [read $fp]
    close $fp

    set values [list]
    foreach line [split $raw_text "\n"] {
        set token [string trim $line]
        if {$token eq ""} {
            continue
        }
        scan $token %x value
        if {$value >= (1 << 19)} {
            set value [expr {$value - (1 << 20)}]
        }
        lappend values $value
    }
    return [join $values ","]
}

proc fir_create_vendor_ip {{module_name fir_vendor_ip_0}} {
    set coeffs [fir_vendor_coeff_vector]
    create_ip -name fir_compiler -vendor xilinx.com -library ip -version 7.2 -module_name $module_name
    set_property -dict [list \
        CONFIG.Filter_Type {Single_Rate} \
        CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
        CONFIG.Number_Channels {1} \
        CONFIG.Data_Width {16} \
        CONFIG.Data_Fractional_Bits {15} \
        CONFIG.Data_Sign {Signed} \
        CONFIG.Coefficient_Width {20} \
        CONFIG.Coefficient_Sign {Signed} \
        CONFIG.CoefficientSource {Vector} \
        CONFIG.CoefficientVector $coeffs \
        CONFIG.Output_Rounding_Mode {Full_Precision} \
        CONFIG.Optimization_Goal {Speed} \
        CONFIG.Clock_Frequency {300.0} \
        CONFIG.Sample_Frequency {300.0} \
        CONFIG.Has_ARESETn {true} \
        CONFIG.DATA_Has_TLAST {Not_Required} \
        CONFIG.S_DATA_Has_FIFO {false} \
        CONFIG.M_DATA_Has_TREADY {false} \
    ] [get_ips $module_name]
    generate_target all [get_ips $module_name]
}
