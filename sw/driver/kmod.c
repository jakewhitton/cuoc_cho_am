#include <linux/init.h>
#include <linux/module.h>

#include "device.h"
#include "ethernet.h"
#include "log.h"

MODULE_AUTHOR("Jake Whitton <jwhitton@alum.mit.edu>");
MODULE_DESCRIPTION("Cuoc Cho Am soundcard");
MODULE_LICENSE("GPL");

static int __init kmod_init(void)
{
    int err;
    
    err = cco_register_driver();
    if (err < 0)
        goto exit_error;

    err = cco_session_manager_init();
    if (err < 0)
        goto undo_register_driver;

    err = cco_ethernet_init();
    if (err < 0)
        goto undo_session_manager_init;

    return 0;

undo_session_manager_init:
    cco_session_manager_exit();
undo_register_driver:
    cco_unregister_driver();
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static void __exit kmod_exit(void)
{
    cco_ethernet_exit();
    cco_session_manager_exit();
    cco_unregister_devices();
    cco_unregister_driver();
}

module_init(kmod_init)
module_exit(kmod_exit)
