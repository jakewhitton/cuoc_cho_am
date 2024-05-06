source [file join [file dirname [info script]] "util.tcl"]

set spec [dict create]
dict set spec "description" \
	"performs synthesis of a design and writes a bitstream to disk"
dict set spec "args" {
	{
		"part"
		"--part|-p"
		"str"
	}
	{
		"top_level_entity"
		"--top-level-entity|-t"
		"str"
	}
	{
		"sources"
		"--sources|-s"
		"file+"
	}
	{
		"constraints"
		"--constraints|-c"
		"file+"
	}
	{
		"output"
		"--output|-o"
		"file"
	}
}
set args [parse_cli_args $spec]

set part [dict get $args "part"]
set top_level_entity [dict get $args "top_level_entity"]
set sources [dict get $args "sources"]
set constraints [dict get $args "constraints"]
set bitstream_location [dict get $args "output"]

# Set part for in-memory project
puts -nonewline "Setting part to \"$part\"..."
if {[lsearch -exact [get_parts] $part] == -1} {
	puts "error"
	exit_with_code "part \"$part\" is not known by vivado"
}
set_part -quiet $part
puts "done!"
puts ""

# Read RTL sources
if {[llength $sources] > 0} {
	foreach source $sources {
		puts -nonewline "Reading RTL source \"$source\"..."
		switch [file extension $source] {
			".vhdl" {
				read_vhdl $source
				puts "done!"
			}
			default {
				puts "error"
				exit_with_code "\"$source\" is not a recognizable RTL source"
			}
		}
	}
	puts ""
}

# Read constraints
if {[llength $constraints] > 0} {
	foreach constraint $constraints {
		puts -nonewline "Reading constraint \"$constraint\"..."
		read_xdc $constraint
		puts "done!"
	}
	puts ""
}

# Synthesize Design
insert_separator "Synthesizing" "yellow"
synth_design -top $top_level_entity -part $part
insert_separator "" "yellow"
puts ""
puts ""
puts ""

# Opt Design 
insert_separator "Optimizing netlist" "green"
opt_design
insert_separator "" "green"
puts ""
puts ""
puts ""

# Place Design
insert_separator "Placing design" "magenta"
place_design
insert_separator "" "magenta"
puts ""
puts ""
puts ""

# Route Design
insert_separator "Routing design" "blue"
route_design
insert_separator "" "blue"
puts ""

# Write out bitstream
puts -nonewline "Writing bitstream to \"$bitstream_location\"..."
write_bitstream -quiet -force $bitstream_location
puts "done!"
