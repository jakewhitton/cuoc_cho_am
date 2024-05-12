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

# Parse flat sources list into heirarchical list of libraries
set libraries [dict create]
set library_name ""
set library {}
for {set i 0} {$i <= [llength $sources]} {incr i} {
    set source [expr {$i == [llength $sources] ? "" : [lindex $sources $i]}]
    if {$i == [llength $sources] || [regexp {^library:(.*)$} $source _ match]} {
        # Save previously constructed library if it exists
        if {[llength $library] > 0} {
            dict set libraries $library_name $library
        }

        # Construct new library if needed
        if {$i < [llength $sources]} {
            set library_name $match
            set library {}
        }
    } else {
        lappend library $source
    }
}

puts "RTL sources = \{"
dict for {library library_sources} $libraries {

    puts -nonewline "    "
    if {$library eq ""} {
        puts -nonewline "<no library>"
    } else {
        puts -nonewline "$library"
    }
    puts ": \["

    foreach source $library_sources {

        # Print source
        puts "        $source"

        # Read source into design
        switch [file extension $source] {
            ".vhdl" {
                if {$library eq ""} {
                    read_vhdl $source
                } else {
                    read_vhdl -library $library $source
                }
            }
            default {
                puts ""
                exit_with_code "\"$source\" is not a recognizable RTL source"
            }
        }
    }
    puts "    \],"
}
puts "}"
puts ""

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
