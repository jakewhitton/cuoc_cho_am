#ifndef CCO_DEVICE_H
#define CCO_DEVICE_H

#include <linux/platform_device.h>
#include <sound/core.h>
#include <sound/pcm.h>

#include <linux/platform_device.h>

#include "mixer.h"

struct cco_device {
    struct platform_device pdev;
    struct snd_card *card;
    spinlock_t mixer_lock;
    int mixer_volume[MIXER_ADDR_LAST+1][2];
    int capture_source[MIXER_ADDR_LAST+1][2];
    int iobox;
    struct snd_kcontrol *cd_volume_ctl;
    struct snd_kcontrol *cd_switch_ctl;
};

#define pdev_to_cco(pdev) container_of((pdev), struct cco_device, pdev)
#define dev_to_cco(dev) container_of((dev), struct cco_device, pdev.dev)

// Driver management
int cco_register_driver(void);
void cco_unregister_driver(void);

// Device management
int cco_register_device(void);
void cco_unregister_device(int id);
void cco_unregister_devices(void);

#endif
