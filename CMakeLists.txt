cmake_minimum_required(VERSION 3.13)
project(sound_card LANGUAGES NONE)

include(scripts/cmake/vivado.cmake)

set(PART xc7a100tcsg324-1)
set(TOP_LEVEL_ENTITY top)

set(RTL_DIR ${PROJECT_SOURCE_DIR}/rtl)
set(RTL_SRCS
    ${RTL_DIR}/top.vhdl
    #library:sw_transport
    #${RTL_DIR}/sw_transport/uart/uart.vhdl
    #${RTL_DIR}/sw_transport/uart/uart_rx.vhdl
    #${RTL_DIR}/sw_transport/uart/uart_tx.vhdl
    #${RTL_DIR}/sw_transport/uart/uart_loopback.vhdl
    library:external_transport
    ${RTL_DIR}/external_transport/spdif/spdif.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_loopback.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_rx.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_rx_serial_bridge.vhdl
    ${RTL_DIR}/external_transport/spdif/spdif_tx_spoof.vhdl
)
set(CONSTRAINT_SRCS
    ${RTL_DIR}/constraints.xdc
)

define_fpga_project(
    PART ${PART}
    TOP_LEVEL_ENTITY ${TOP_LEVEL_ENTITY}
    RTL_SRCS ${RTL_SRCS}
    CONSTRAINT_SRCS ${CONSTRAINT_SRCS}
)
