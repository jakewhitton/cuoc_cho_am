#include <linux/init.h>
#include <linux/module.h>

#include "device.h"

MODULE_AUTHOR("Jake Whitton <jwhitton@alum.mit.edu>");
MODULE_DESCRIPTION("Cuoc Cho Am soundcard");
MODULE_LICENSE("GPL");

module_param_array(idx, int, NULL, 0444);
MODULE_PARM_DESC(idx, "Index value for cco soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for cco soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this cco soundcard.");
module_param_array(pcm_devs, int, NULL, 0444);
MODULE_PARM_DESC(pcm_devs, "PCM devices # (0-4) for cco driver.");
module_param_array(pcm_substreams, int, NULL, 0444);
MODULE_PARM_DESC(pcm_substreams, "PCM substreams # (1-128) for cco driver.");

static int __init kmod_init(void)
{
    return cco_register_all();
}

static void __exit kmod_exit(void)
{
    cco_unregister_all();
}

module_init(kmod_init)
module_exit(kmod_exit)
