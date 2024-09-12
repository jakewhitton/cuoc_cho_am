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

extern int   idx           [SNDRV_CARDS]; /* Index 0-MAX */
extern char *id            [SNDRV_CARDS]; /* ID for this card */
extern bool  enable        [SNDRV_CARDS];
extern int   pcm_devs      [SNDRV_CARDS];
extern int   pcm_substreams[SNDRV_CARDS];
extern int   mixer_volume_level_min;
extern int   mixer_volume_level_max;
extern bool  fake_buffer;

extern struct platform_device *devices[SNDRV_CARDS];

int cco_register_all(void);
void cco_unregister_all(void);

#endif
