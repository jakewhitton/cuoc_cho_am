source [file join [file dirname [info script]] "util.tcl"]

set spec [dict create]
dict set spec "description" \
    "programs bitstream onto the device"
dict set spec "args" {
    {
        "part"
        "--part|-p"
        "str"
    }
    {
        "bitstream"
        "--bitstream|-b"
        "file"
    }
}
set args [parse_cli_args $spec]

set part [dict get $args "part"]
set bitstream [dict get $args "bitstream"]

# Bring up hw server
puts -nonewline "Bringing up hw server..."
open_hw_manager -quiet
connect_hw_server -quiet
puts "done!"
puts ""

# Locate device to program
puts -nonewline "Looking for device with part \"$part\"..."
open_hw_target -quiet
set device ""
set found_device "false"
foreach hw_device [get_hw_devices -quiet] {
    if {[string match "[get_property PART $hw_device]*" $part]} {
        set device $hw_device
        set found_device "true"
        break
    }
}
if {$found_device} {
    puts "done!"
} else {
    puts "error"
    puts ""
    disconnect_hw_server -quiet
    close_hw_manager -quiet
    exit_with_code "could not find device\n"
}
puts ""

# Configure & program target device
puts -nonewline "Programming device..."
current_hw_device -quiet $device
refresh_hw_device -quiet -update_hw_probes false $device
set_property -quiet PROGRAM.FILE $bitstream $device
program_hw_devices -quiet $device
refresh_hw_device -quiet $device
puts "done!"
puts ""

# Teardown hw server
puts -nonewline "Tearing down hw server..."
close_hw_target -quiet
disconnect_hw_server -quiet
close_hw_manager -quiet
puts "done!"
puts ""
