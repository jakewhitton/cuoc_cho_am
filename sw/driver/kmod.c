#include <linux/init.h>
#include <linux/err.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/time.h>
#include <linux/wait.h>
#include <linux/hrtimer.h>
#include <linux/math64.h>
#include <linux/module.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/tlv.h>
#include <sound/pcm.h>
#include <sound/info.h>
#include <sound/initval.h>

#include "pcm.h"
#include "timer.h"
#include "device.h"
#include "mixer.h"

MODULE_AUTHOR("Jaroslav Kysela <perex@perex.cz>");
MODULE_DESCRIPTION("Dummy soundcard (/dev/null)");
MODULE_LICENSE("GPL");

module_param_array(idx, int, NULL, 0444);
MODULE_PARM_DESC(idx, "Index value for dummy soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for dummy soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this dummy soundcard.");
module_param_array(pcm_devs, int, NULL, 0444);
MODULE_PARM_DESC(pcm_devs, "PCM devices # (0-4) for dummy driver.");
module_param_array(pcm_substreams, int, NULL, 0444);
MODULE_PARM_DESC(pcm_substreams, "PCM substreams # (1-128) for dummy driver.");
module_param(mixer_volume_level_min, int, 0444);
MODULE_PARM_DESC(mixer_volume_level_min, "Minimum mixer volume level for dummy driver. Default: -50");
module_param(mixer_volume_level_max, int, 0444);
MODULE_PARM_DESC(mixer_volume_level_max, "Maximum mixer volume level for dummy driver. Default: 100");
module_param(fake_buffer, bool, 0444);
MODULE_PARM_DESC(fake_buffer, "Fake buffer allocations.");

static int __init kmod_init(void)
{
	return snd_dummy_register_all();
}

static void __exit kmod_exit(void)
{
    snd_dummy_unregister_all();
}

module_init(kmod_init)
module_exit(kmod_exit)
