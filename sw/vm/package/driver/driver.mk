DRIVER_VERSION       = 0.0.1
#DRIVER_SITE          = $(CURDIR)
DRIVER_SITE          = $(realpath $(BR2_EXTERNAL_VM_PATH)/../driver)
DRIVER_SITE_METHOD   = local
DRIVER_LICENSE       = GPL-2.0
DRIVER_LICENSE_FILES = LICENSE

$(eval $(kernel-module))
$(eval $(generic-package))
