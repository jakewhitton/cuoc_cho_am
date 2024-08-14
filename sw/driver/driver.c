#include <linux/kernel.h>
#include <linux/module.h>

#include "helper.h"

static int __init kmod_init(void)
{
	printk(KERN_INFO "kernel module is loaded: %d\n", get_random_int());
	return 0;
}

static void __exit kmod_exit(void)
{
	printk(KERN_INFO "kernel module is unloaded: %d\n", get_random_int());
}

module_init(kmod_init);
module_exit(kmod_exit);

MODULE_LICENSE("GPL v2");
