#!/bin/bash

REPO_DIR="/home/jake/programming/repos/cuoc_cho_am"
RTL_DIR="${REPO_DIR}/rtl"

set -e

# Analyze files
[ ! -d obj ] && mkdir obj
pushd obj > /dev/null
ghdl -a --std=08 -frelaxed -fsynopsys -fexplicit \
    ${RTL_DIR}/external_transport/spdif/spdif.vhdl \
    ${RTL_DIR}/external_transport/spdif/spdif_rx.vhdl \
    ${RTL_DIR}/external_transport/spdif/spdif_rx_serial_bridge.vhdl \
    ${RTL_DIR}/external_transport/spdif/sim/sim_spdif.vhdl \
    ${RTL_DIR}/external_transport/spdif/sim/tb_spdif_rx.vhdl
ghdl -e --std=08 -frelaxed -fsynopsys -fexplicit tb_spdif_rx
popd > /dev/null

./obj/tb_spdif_rx --vcd=tb_spdif_rx.vcd
