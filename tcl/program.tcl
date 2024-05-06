source [file join [file dirname [info script]] "util.tcl"]

set spec [dict create]
dict set spec "description" \
	"programs bitstream onto the device"
dict set spec "args" {
	{
		"bitstream"
		"--bitstream|-b"
		"file"
	}
}
set args [parse_cli_args $spec]

set bitstream [dict get $args "bitstream"]

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set_property PROGRAM.FILE $bitstream $device

program_hw_devices $device
refresh_hw_device $device
