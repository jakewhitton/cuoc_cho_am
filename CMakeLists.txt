cmake_minimum_required(VERSION 3.13)
project(sound_card LANGUAGES NONE)

include(scripts/cmake/vivado.cmake)

set(PART xc7a100tcsg324-1)
set(TOP_LEVEL_ENTITY uart_rx)

set(RTL_DIR ${PROJECT_SOURCE_DIR}/rtl)
set(RTL_SRCS
    ${RTL_DIR}/transport/uart_rx.vhdl
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
