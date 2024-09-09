ccflags-y := -DDEBUG -g -std=gnu99 -Wno-declaration-after-statement

obj-m += cco.o
cco-objs += kmod.o
cco-objs += device.o
cco-objs += pcm.o
cco-objs += timer.o
cco-objs += mixer.o

.PHONY: all clean

all:
	$(MAKE) -C '$(LINUX_DIR)' M='$(CURDIR)' modules

clean:
	$(MAKE) -C '$(LINUX_DIR)' M='$(CURDIR)' clean
