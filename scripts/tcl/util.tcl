proc parse_cli_args {spec} {

	set spec [compile_spec $spec]

    # Used locally to simplify implementation
    set null "\uFFFF"
    if {$null ne $null || $null eq "" || $null eq {}} {
        exit_with_code "null value isn't functioning"
    }

    set result [dict create]
    proc define_arg {tokens arg_spec} {
        upvar result result
		set arg [dict get $arg_spec "name"]
		set value [lrange $tokens 1 end]
        dict lappend result $arg {*}$value
    }

    set tokens {}
    set arg_spec $null
    for {set i 0} {$i < [llength $::argv]} {incr i} {

        set token [lindex $::argv $i]

        if { $arg_spec eq $null } {
			if {[regexp {^-h$|^--help$} $token]} {
				exit_with_code [get_usage_string $spec] 0
            } elseif {[dict exists $spec "flags" $token]} {
                set arg_spec [dict get $spec "flags" $token]
            } else {
                exit_with_code [format %s\n\n%s              \
								"unknown cli arg \"$token\"" \
								[get_usage_string $spec]]
            }
        }
        lappend tokens $token

        # All tokens related to the definition of one cli arg have been received when
        # any of the following conditions occur:
        #
        #   1. There is no next token (i.e. we've reached the end of $::argv)
        #
        #   2. The next token is a known cli flag
        #
        #   3. The arg spec states that the arg takes a specific, fixed number of
        #      values, and we have collected all of them
		#
        #   4. The next token looks like a cli flag (i.e. prefixed with '-' or '--')
		#      but isn't one that we recognize
        #
		set next_token [expr {$i + 1 < [llength $::argv]
							    ? [lindex $::argv [expr $i + 1]]
							    : $null}]
		set finished_fixed_size_arg [expr {![dict get $arg_spec "variadic"] && \
            [dict get $arg_spec "num_required_values"] == [expr [llength $tokens] - 1]}]
        if {$next_token eq $null                   || \
            [dict exists $spec "args" $next_token] || \
			$finished_fixed_size_arg               || \
			[regexp "^--?" $next_token]}              \
        {
            define_arg $tokens $arg_spec
            set tokens {}
            set arg_spec $null
        }
    }

	validate_cli_args $result $spec

	print_arg_values $result $spec

    rename define_arg ""

    return $result
}

proc compile_spec {spec} {

	# Record script name
	dict set spec "name" [file tail $::argv0]

	# Replace human readable args spec with two machine-readable maps:
	#
	#   1. "args": maps arg name => arg spec
	#
	#   2. "flags" maps flag => arg spec
	#
	set human_arg_specs [dict get $spec "args"]
	dict set spec "args" [dict create]
	dict set spec "flags" [dict create]
    foreach human_arg_spec $human_arg_specs {
        lassign $human_arg_spec arg flags type

        set arg_spec [dict create]
		dict set arg_spec "name" $arg
		dict set arg_spec "flags" $flags

		# Validate & parse type spec
		set valid_base_type_re "(int|str|file)"
		set valid_compound_type_re [format {%s(\*|\+|\{[0-9]+\})?} $valid_base_type_re]
		set valid_type_re [format {^%1$s$|^\[%1$s\]$} $valid_compound_type_re]
		if {![regexp $valid_type_re $type _ m1 m2 m3 m4]} {
			exit_with_code "invalid type \"$type\" in spec"
		}

		# Parse out subfields from type spec
		set required [expr {$m1 eq "" ? "false" : "true"}]
		if {$required} {
			set base_type $m1
			set length_spec $m2
		} else {
			set base_type $m3
			set length_spec $m4
		}

		# Record mandatory fields
		dict set arg_spec "required" $required
		dict set arg_spec "base_type" $base_type

		# Record "variadic" and "num_required_values" depending on type spec
		switch -regexp -matchvar match -- $length_spec {
			{\*} {
				dict set arg_spec "variadic" "true"
				dict set arg_spec "num_required_values" 0
			}
			{\+} {
				dict set arg_spec "variadic" "true"
				dict set arg_spec "num_required_values" 1
			}

			{\{([0-9]+)\}} {
				# Explicit number of args
				dict set arg_spec "variadic" "false"
				dict set arg_spec "num_required_values" [lindex $match 1]
			}

			default {
				# No length spec means it only accepts one arg
				dict set arg_spec "variadic" "false"
				dict set arg_spec "num_required_values" 1
			}
		}

        # Insert mapping of arg name => arg spec
		if {[dict exists $spec "args" $arg]} {
			exit_with_code "duplicate arg name \"$arg\" in spec"
		} else {
			dict set spec "args" $arg $arg_spec
		}

        # Insert mapping for cli flag => arg spec for the cli flag (and all aliases)
        foreach flag [split $flags |] {
            if {[dict exists $spec "flags" $flag]} {
                exit_with_code "duplicate cli flag \"$flag\" in spec"
            } else {
                dict set spec "flags" $flag $arg_spec
            }
        }
    }

    return $spec
}

proc validate_cli_args {args spec} {

    dict for {arg arg_spec} [dict get $spec "args"] {

		# Extract needed information from arg spec
		set flags [dict get $arg_spec "flags"]
		set required [dict get $arg_spec "required"]
		set num_required_values [dict get $arg_spec "num_required_values"]
		set variadic [dict get $arg_spec "variadic"]

		if {[dict exists $args $arg]} {
			set value [dict get $args $arg]
			set num_supplied_values [llength $value]

			# Verify supplied args have correct number of values
			if { ( $variadic && $num_supplied_values <  $num_required_values) || \
				 (!$variadic && $num_supplied_values != $num_required_values) }  \
			{
				set msg "cli arg \"$flags\" requires "
				if {$variadic} {
					append msg "at least "
				}
				append msg "$num_required_values value"
				if {$num_required_values != 1} {
					append msg "s"
				}
				append msg ", but $num_supplied_values were provided"

				exit_with_code [format %s\n\n%s \
								$msg            \
								[get_usage_string $spec]]
			}
		} else {
			# Verify all required args are supplied
			if {$required} {
				exit_with_code [format %s\n\n%s              \
								"missing required cli arg \"$flags\"" \
								[get_usage_string $spec]]
			}
		}
    }
}

proc get_usage_string {spec} {

	set s ""

	set name [dict get $spec "name"]
	if {[dict exists $spec "description"]} {
		set description [dict get $spec "description"]
		append s "$name -- $description\n\n"
	}

	# Describe program purpose
	set first_line "Usage: $name "
	set prefix [string repeat " " [string length $first_line]]
	append s $first_line
	
	dict for {arg arg_spec} [dict get $spec "args"] {

		# Extract needed information from arg spec
		set required [dict get $arg_spec "required"]
		set flags [dict get $arg_spec "flags"]
		set variadic [dict get $arg_spec "variadic"]
		set num_required_values [dict get $arg_spec "num_required_values"]
		set base_type [dict get $arg_spec "base_type"]

		# Begin arg definition
		
		if {$arg ne [lindex [dict get $spec "args"] 0]} {
			append s $prefix
		}
		if {!$required} {
			append s "\[ "
		}

		# Print flags
		append s "$flags"

		# Print values
		for {set i 1} {$i <= $num_required_values} {incr i} {
			append s [format { <%s>} $base_type]
		}
		if {$variadic} {
			append s [format { [<%s>...]} $base_type]
		}

		# End arg definition
		if {!$required} {
			append s " \]"
		}
		append s "\n"
	}

	return $s
}

proc print_arg_values {args spec} {

	set name [dict get $spec name]
	puts "\n$name options:"
	dict for {arg arg_spec} [dict get $spec "args"] {
		if {[dict exists $args $arg]} {
			set value [dict get $args $arg]

			puts ""
			if {[llength $value] == 0} {
				puts "    $arg: \[\]"
			} elseif {[llength $value] == 1} {
				puts "    $arg: $value"
			} else {
				puts "    $arg: \["
				for {set i 0} {$i < [llength $value]} {incr i} {
					set e [lindex $value $i]
					if {$i < [expr [llength $value] - 1]} {
						puts "        $e,"
					} else {
						puts "        $e"
					}
				}
				puts "    \]"

			}
		}
	}
	puts ""

}

proc exit_with_code {msg {error_code 1}} {
	if {$error_code == 0} {
		puts "$msg"
	} else {
		puts stderr "Error: $msg"
	}
    exit $error_code
}

# Adapted from: https://wiki.tcl-lang.org/page/Generating+random+strings
proc generate_random_string {length {chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"}} {
    set range [expr {[string length $chars]-1}]

    set txt ""
    for {set i 0} {$i < $length} {incr i} {
       set pos [expr {int(rand()*$range)}]
       append txt [string range $chars $pos $pos]
    }
    return $txt
}

proc run_and_return_stdout {args} {
	set tmpfile [format "/tmp/tmp_%s" [generate_random_string 8]]
	exec {*}$args >& $tmpfile
	set fp [open $tmpfile r]
	set file_data [read $fp]
	close $fp
	file delete -force $tmpfile

	return $file_data
}

set colors [dict create]
dict set colors "red" "\033\[1;31m"
dict set colors "green" "\033\[1;32m"
dict set colors "yellow" "\033\[1;33m"
dict set colors "blue" "\033\[1;34m"
dict set colors "magenta" "\033\[1;35m"
dict set colors "cyan" "\033\[1;36m"
dict set colors "white" "\033\[1;37m"
dict set colors "reset" "\033\[0m"

proc insert_separator {{label ""} {color ""}} {
	set w [string trim [run_and_return_stdout tput cols]]

	set l [string length $label]
	if {$l > $w} {
		exit_with_code "$label too large"
	}

	set budget [expr $w - $l]

	set prefix_length [expr $budget / 2]
	set suffix_length [expr ($budget / 2) + ($budget % 2)]

	set prefix ""
	for {set i 0} {$i < $prefix_length} {incr i} {
		if {$i == 0} {
			append prefix "#"
		} else {
			append prefix "="
		}
	}

	set suffix ""
	for {set i 0} {$i < $suffix_length} {incr i} {
		if {$i < $suffix_length - 1} {
			append suffix "="
		} else {
			append suffix "#"
		}
	}

	set separator "$prefix$label$suffix"
	upvar colors colors
	if {$color ne "" && [dict exists $colors $color]} {
		set color [dict get $colors $color]
		set reset [dict get $colors "reset"]
		set separator "$color$separator$reset"
	}

	puts $separator
}
