#include <linux/init.h>
#include <linux/module.h>

#include "device.h"

MODULE_AUTHOR("Jake Whitton <jwhitton@alum.mit.edu>");
MODULE_DESCRIPTION("Cuoc Cho Am soundcard");
MODULE_LICENSE("GPL");

static int __init kmod_init(void)
{
    int err;
    
    err = cco_register_driver();
    if (err < 0) {
        printk(KERN_ERR "cco: cco_register_driver() failed");
        return err;
    }

    // Create a single device upon module loading
    //
    // Note: once ethernet communication with the FPGA is implemented, we will defer
    // device creation to the point at which handshake over ethernet is successfully
    // completed.
    //
    err = cco_register_device();
    if (err < 0) {
        printk(KERN_ERR "cco: cco_register_device() failed");
        cco_unregister_driver();
        return err;
    }

    return 0;
}

static void __exit kmod_exit(void)
{
    cco_unregister_devices();
    cco_unregister_driver();
}

module_init(kmod_init)
module_exit(kmod_exit)
