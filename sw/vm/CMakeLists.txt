# Cmake wrapper around buildroot external tree build

set(DRIVER_VERSION 0.0.1)
file(GLOB DRIVER_SRC ../driver/*)

# Defer to makefile in buildroot external tree for constructing
# artifacts necessary for spawning qemu vm & testing kernel driver
#
# Note: removal of driver build dir is a workaround to force
# buildroot to rebuild the kernel driver buildroot package, since
# buildroot does not attempt to rsync source files again when
# they're updated
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/images/rootfs.ext2
	COMMAND
	    rm -rf ${CMAKE_CURRENT_BINARY_DIR}/build/driver-${DRIVER_VERSION} # see above note
	COMMAND
	    BUILDROOT_OUTPUT_DIR=${CMAKE_CURRENT_BINARY_DIR}
	    DRIVER_VERSION=${DRIVER_VERSION}
	    make -C ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building QEMU rootfs image"
	DEPENDS ${DRIVER_SRC}
)

add_custom_target(
    sw
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/images/rootfs.ext2
)

# Spawn qemu for testing kernel driver
add_custom_target(
    qemu
	COMMAND
	    qemu-system-x86_64
        -M pc
        -kernel ${CMAKE_CURRENT_BINARY_DIR}/images/bzImage
        -drive file=${CMAKE_CURRENT_BINARY_DIR}/images/rootfs.ext2,if=virtio,format=raw
        -append "root=/dev/vda console=ttyS0"
        -net user,hostfwd=tcp:127.0.0.1:3333-:22
        -net nic,model=virtio
        -nographic
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/images/rootfs.ext2
)
