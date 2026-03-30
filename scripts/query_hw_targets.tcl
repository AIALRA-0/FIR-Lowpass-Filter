set server_url "localhost:3121"
if {[info exists ::env(HW_SERVER_URL)] && $::env(HW_SERVER_URL) ne ""} {
    set server_url $::env(HW_SERVER_URL)
}

open_hw_manager
connect_hw_server -url $server_url

set targets [get_hw_targets *]
puts "HW_QUERY|server_url|$server_url"
puts "HW_QUERY|target_count|[llength $targets]"

foreach t $targets {
    current_hw_target $t
    set open_rc [catch {open_hw_target $t} open_msg]
    set open_msg_clean [string map {"\n" " " "\r" " " "|" "/"} $open_msg]
    set devs [get_hw_devices]
    puts "HW_TARGET|$t|$open_rc|$open_msg_clean|[llength $devs]"
    foreach d $devs {
        set part [get_property PART $d]
        set idcode [get_property IDCODE $d]
        puts "HW_DEVICE|$t|$d|$part|$idcode"
    }
    catch {close_hw_target $t}
}

catch {disconnect_hw_server $server_url}
close_hw_manager
exit
