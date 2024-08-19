#=================================Configuration================================#
# Target part for design
#
# Note: current build is for Arty A7-100T
set(PART xc7a100tcsg324-1)

# Top level entity for design
set(TOP_LEVEL_ENTITY top)

# RTL sources
#
# Note: use library:<name> to indicate that all following source
# files should be packaged together in a VHDL library
set(RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)
set(RTL_SRCS
    # RTL sources that don't belong to any library
    ${RTL_DIR}/top.vhdl

    # Communication between host <-> fpga
    library:sw_transport
    ${RTL_DIR}/sw_transport/uart/uart.vhdl
    ${RTL_DIR}/sw_transport/uart/uart_rx.vhdl
    ${RTL_DIR}/sw_transport/uart/uart_tx.vhdl
    ${RTL_DIR}/sw_transport/uart/uart_loopback.vhdl

    # Communication between fpga <-> DAC/ADC
    library:external_transport
    ${RTL_DIR}/external_transport/spdif/spdif.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_rx.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_rx_serial_bridge.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_tx.vhdl
    #${RTL_DIR}/external_transport/spdif/spdif_loopback.vhdl
    #${RTL_DIR}/external_transport/spdif/spdif_tx_spoof.vhdl

    # Helper utilities
	library:util
    ${RTL_DIR}/util/signals/signals.vhdl
    ${RTL_DIR}/util/signals/clk_generator.vhdl
    ${RTL_DIR}/util/signals/phaser.vhdl
)

# Constraint sources
set(CONSTRAINT_SRCS
    ${RTL_DIR}/constraints.xdc
)
#==============================================================================#



#===================================Building===================================#
# Command for spawning vivado process in batch mode
set(VIVADO_CMD
  vivado -quiet -notrace -nolog -nojournal -mode batch
)

# Even though we pass `-notrace -nolog -nojournal` to vivado, it
# still creates artifacts in the working directory as it runs the
# supplied TCL script
#
# To keep things tidy, we give the vivado process its own special
# working directory so that these artifacts will be kept organized
set(VIVADO_WORKING_DIR ${CMAKE_CURRENT_BINARY_DIR}/.vivado)
file(MAKE_DIRECTORY ${VIVADO_WORKING_DIR})

# Extract actual filenames from RTL_SRCS for use in DEPENDS for custom commands
set(RTL_SRCS_FILES ${RTL_SRCS})
list(
    FILTER RTL_SRCS_FILES
    EXCLUDE REGEX "^library:.*$"
)

# Define custom command for bitstream generation
set(TCL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scripts/tcl)
set(BITSTREAM_PATH ${CMAKE_CURRENT_BINARY_DIR}/${TOP_LEVEL_ENTITY}.bit)
add_custom_command(
    OUTPUT ${BITSTREAM_PATH}
    COMMAND
        ${VIVADO_CMD}
            -source ${TCL_DIR}/build.tcl
            -tclargs
            --part ${PART}
            --top-level-entity ${TOP_LEVEL_ENTITY}
            --sources ${RTL_SRCS}
            --constraints ${CONSTRAINT_SRCS}
            --output ${BITSTREAM_PATH}
    WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
    DEPENDS
        ${RTL_SRCS_FILES}
        ${CONSTRAINT_SRCS}
        ${TCL_DIR}/build.tcl
)

# Define custom target for bitstream generation
add_custom_target(
    hw ALL
    DEPENDS ${BITSTREAM_PATH}
    VERBATIM
)

# Define custom target for bitstream programming
add_custom_target(
    program
    COMMAND
        ${VIVADO_CMD}
            -source ${TCL_DIR}/program.tcl
            -tclargs
            --part ${PART}
            --bitstream ${BITSTREAM_PATH}
    WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
    DEPENDS
        ${BITSTREAM_PATH}
        ${TCL_DIR}/program.tcl
)
#==============================================================================#
