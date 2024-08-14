SRC_DIR := $(realpath $(BR2_EXTERNAL_VM_PATH)/../driver)

obj-m += $(addsuffix .o, $(notdir $(basename $(wildcard $(SRC_DIR)/*.c))))
ccflags-y := -DDEBUG -g -std=gnu99 -Wno-declaration-after-statement

.PHONY: all clean

all: /tmp/test
	$(MAKE) -C '$(LINUX_DIR)' M='$(SRC_DIR)' modules

clean:
	$(MAKE) -C '$(LINUX_DIR)' M='$(SRC_DIR)' clean
