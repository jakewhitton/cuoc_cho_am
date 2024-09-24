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
set(RTL_SRC
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
    ${RTL_DIR}/external_transport/spdif/spdif_trx.vhdl
    #${RTL_DIR}/external_transport/spdif/spdif_loopback.vhdl
    #${RTL_DIR}/external_transport/spdif/spdif_tx_spoof.vhdl

    # Helper utilities
    library:util
    ${RTL_DIR}/util/signals/signals.vhdl
    ${RTL_DIR}/util/signals/clk_generator.vhdl
    ${RTL_DIR}/util/signals/phaser.vhdl
)

# Define each IP module that needs to be instantiated and synthesized
#
# Each module listed will result in a call to `generate_ip.tcl --ip <module>`,
# which is responsible for generating ${IP_SRCS_DIR}/<module>/<module>.xci.
#
# These generated .xci files will, in turn, be passed for synthesis via
# `build.tcl <...> --ip <xci_file> [<xci_file> ...]`
#
# When an entry is added here, you must provide an IP configuration by modifying
# `get_ip_config` in generate_ip.tcl
set(IP_MODULES
    pll
)

# Constraint sources
set(CONSTRAINT_SRCS
    ${RTL_DIR}/constraints.xdc
)

# Path where final synthesized bitstream should reside
set(BITSTREAM_PATH ${CMAKE_CURRENT_BINARY_DIR}/${TOP_LEVEL_ENTITY}.bit)
#==============================================================================#



#===================================Building===================================#
# Directory where TCL scripts are being stored
set(TCL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scripts/tcl)

# Command for spawning vivado process in batch mode
set(VIVADO_CMD
  vivado -quiet -notrace -nolog -nojournal -mode batch
)

# Directory where vivado process will be spawned
#
# Note: passing `-notrace -nolog -nojournal` is not enough to prevent vivado
# from writing artifacts to the CWD.  This variable allows us to keep these
# artifacts neat and organized.
set(VIVADO_WORKING_DIR ${CMAKE_CURRENT_BINARY_DIR}/.vivado)
file(MAKE_DIRECTORY ${VIVADO_WORKING_DIR})

# By deafult, for a given IP module, vivado splits IP generation artifacts
# across two different directories:
#
#   1. $(cwd)/.srcs/sources_1/ip/<module>: holds <module>.xci
#
#   2. $(cwd)/.gen/sources_1/ip/<module>: holds everything else
#
set(IP_SRCS_DIR ${VIVADO_WORKING_DIR}/.srcs/sources_1/ip)
set(IP_GEN_DIR ${VIVADO_WORKING_DIR}/.gen/sources_1/ip)

# Perform handling for each IP module
set(IP_XCI_SRC "")
foreach(IP_MODULE IN LISTS IP_MODULES)
    # Add custom command for generating IP module
    set(XCI_PATH ${IP_SRCS_DIR}/${IP_MODULE}/${IP_MODULE}.xci)
    add_custom_command(
        OUTPUT ${XCI_PATH}
        COMMAND
		    rm -rf "${IP_SRCS_DIR}/${IP_MODULE}"
        COMMAND
		    rm -rf "${IP_GEN_DIR}/${IP_MODULE}"
        COMMAND
            ${VIVADO_CMD}
                -source ${TCL_DIR}/generate_ip.tcl
                -tclargs
                --part ${PART}
                --ip ${IP_MODULE}
        WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
        DEPENDS ${TCL_DIR}/generate_ip.tcl
        COMMENT "Generating IP for \"${IP_MODULE}\" module"
    )

    # Add generated IP core to IP_XCI_SRC
    list(APPEND IP_XCI_SRC ${XCI_PATH})
endforeach()

# If using IP, bundle all IP-related src under a newly created 'ip' library
if(IP_XCI_SRC)
    list(APPEND RTL_SRC "library:ip")
    list(APPEND RTL_SRC ${IP_XCI_SRC})
endif()

# Extract actual filenames from RTL_SRC for use in DEPENDS for custom commands
set(RTL_SRC_FILES ${RTL_SRC})
list(
    FILTER RTL_SRC_FILES
    EXCLUDE REGEX "^library:.*$"
)

# Define custom command for bitstream generation
add_custom_command(
    OUTPUT ${BITSTREAM_PATH}
    COMMAND
        ${VIVADO_CMD}
            -source ${TCL_DIR}/build.tcl
            -tclargs
            --part ${PART}
            --top-level-entity ${TOP_LEVEL_ENTITY}
            --sources ${RTL_SRC}
            --constraints ${CONSTRAINT_SRCS}
            --output ${BITSTREAM_PATH}
    WORKING_DIRECTORY ${VIVADO_WORKING_DIR}
    DEPENDS
        ${RTL_SRC_FILES}
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
