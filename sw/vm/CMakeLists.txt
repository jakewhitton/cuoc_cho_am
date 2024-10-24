#=================================Configuration================================#
set(DRIVER_VERSION 0.0.1)
file(GLOB DRIVER_SRC ../driver/*)
#==============================================================================#



#===================================Building===================================#
# Give helpful error if buildroot submodule has not yet been cloned
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/buildroot/.git")
    message(FATAL_ERROR
	    "Buildroot submodule has not been cloned...\n"
        "Please run `git submodule update --init --recursive`"
	)
endif()

# Query number of processors on current machine for passing to -j for make
execute_process(COMMAND nproc OUTPUT_VARIABLE NPROC OUTPUT_STRIP_TRAILING_WHITESPACE)

# Define custom command for generating rootfs image that qemu boots from
#
# Notes:
#
#   1. Buildroot packages that utilize 'local' as a SITE_METHOD do
#      not make any effort to detect if the sources have been
#      updated.  Once it successfully builds it once, it will not
#      rebuild even after sources have been updated.
#
#      Because of this, we manually nuke the build directory for
#      the kernel driver each time.  Doing so forces buildroot to
#      rsync the sources for the package, which causes changes in
#      the sources to successfully be picked up.
#
#   2. The makefile in this directory wraps the building of a
#      buildroot external tree.  The environment variable
#      `BUILDROOT_OUTPUT_DIR` is required to specify where the
#      buildroot build artifacts should be placed
#
set(ROOTFS_IMAGE_PATH ${CMAKE_CURRENT_BINARY_DIR}/images/rootfs.ext2)
add_custom_command(
    OUTPUT ${ROOTFS_IMAGE_PATH}
    COMMAND
        # See above note 1
        rm -rf ${CMAKE_CURRENT_BINARY_DIR}/build/driver-${DRIVER_VERSION} 
    COMMAND
        # See above note 2
        BUILDROOT_OUTPUT_DIR=${CMAKE_CURRENT_BINARY_DIR} 
        DRIVER_VERSION=${DRIVER_VERSION}
        make -C ${CMAKE_CURRENT_SOURCE_DIR} -j${NPROC}
    COMMENT "Building QEMU rootfs image"
    DEPENDS ${DRIVER_SRC}
)

# Define custom target for generating rootfs image that qemu boots from
add_custom_target(
    sw ALL
    DEPENDS ${ROOTFS_IMAGE_PATH}
    VERBATIM
)

# Define custom target for spawning qemu
add_custom_target(
    qemu
    COMMAND
        sudo qemu-system-x86_64
            -M pc
            -kernel ${CMAKE_CURRENT_BINARY_DIR}/images/bzImage
            -drive file=${ROOTFS_IMAGE_PATH},if=virtio,format=raw
            -append "root=/dev/vda console=ttyS0"
            -netdev tap,id=mynet0,ifname=tap0,script=no,downscript=no
            -device virtio-net-pci,netdev=mynet0,mac=52:55:00:d1:55:01
            -nographic
    DEPENDS ${ROOTFS_IMAGE_PATH}
)
#==============================================================================#
