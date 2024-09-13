#ifndef CCO_DEVICE_H
#define CCO_DEVICE_H

#include <linux/platform_device.h>
#include <sound/core.h>
#include <sound/pcm.h>

#include "mixer.h"

struct cco_device {
    struct snd_card *card;
    struct snd_pcm *pcm;
    struct snd_pcm_hardware pcm_hw;
    spinlock_t mixer_lock;
    int mixer_volume[MIXER_ADDR_LAST+1][2];
    int capture_source[MIXER_ADDR_LAST+1][2];
    int iobox;
    struct snd_kcontrol *cd_volume_ctl;
    struct snd_kcontrol *cd_switch_ctl;
};

int cco_register_driver(void);
void cco_unregister_driver(void);

int cco_register_device(void);
void cco_unregister_devices(void);

#endif
