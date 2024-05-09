function(define_fpga_project)
    cmake_parse_arguments(
        "" # no prefix 
        "" # no boolean args
        "PART;TOP_LEVEL_ENTITY"
        "RTL_SRCS;CONSTRAINT_SRCS"
    )

	# Print fpga project parameters
	message("")
    message("Generating fpga project definition:")
    message("    PART: ${PART}")
    message("    TOP_LEVEL_ENTITY: " ${TOP_LEVEL_ENTITY})
    message("    RTL_SRCS: ${RTL_SRCS}")
    message("    CONSTRAINT_SRCS: " ${CONSTRAINT_SRCS})
	message("")

	set(TCL_DIR ${PROJECT_SOURCE_DIR}/scripts/tcl)
    set(BITSTREAM_PATH ${CMAKE_CURRENT_BINARY_DIR}/${TOP_LEVEL_ENTITY}.bit)

    set(VIVADO_WORKING_DIR ${CMAKE_CURRENT_BINARY_DIR}/.vivado)
	file(MAKE_DIRECTORY ${VIVADO_WORKING_DIR})

	# Extract actual filenames from RTL_SRCS for DEPENDS
	set(RTL_SRCS_FILES ${RTL_SRCS})
	list(
	    FILTER RTL_SRCS_FILES
	    EXCLUDE REGEX "^library:.*$"
	)

	message(${RTL_SRCS_FILES} ${CONSTRAINT_SRCS})
	
    # Define command for bitstream generation
    add_custom_command(
        OUTPUT ${BITSTREAM_PATH}
        COMMAND vivado -quiet -notrace -nolog -nojournal -mode batch -source ${TCL_DIR}/build.tcl -tclargs
            --part ${PART}
            --top-level-entity ${TOP_LEVEL_ENTITY}
            --sources ${RTL_SRCS}
            --constraints ${CONSTRAINT_SRCS}
            --output ${BITSTREAM_PATH}
		WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
		DEPENDS ${RTL_SRCS_FILES} ${CONSTRAINT_SRCS}
    )

    # Define target for bitstream generation
    add_custom_target(
        build ALL
        DEPENDS ${BITSTREAM_PATH}
		VERBATIM
    )

	# Define target for bitstream programming
	add_custom_target(
        program
        COMMAND vivado -quiet -notrace -nolog -nojournal -mode batch -source ${TCL_DIR}/program.tcl -tclargs
            --part ${PART}
            --bitstream ${BITSTREAM_PATH}
		WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
		DEPENDS ${BITSTREAM_PATH}
	)
endfunction(define_fpga_project)
