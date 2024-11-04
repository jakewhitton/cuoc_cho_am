#ifndef CCO_DEVICE_H
#define CCO_DEVICE_H

#include <linux/platform_device.h>
#include <linux/skbuff.h>
#include <sound/core.h>

#include "mixer.h"

#define PCM_DEVICES_PER_CARD      1
#define PCM_SUBSTREAMS_PER_DEVICE 2

struct cco_device {
    struct platform_device pdev;
    struct snd_card *card;
    struct cco_mixer mixer;
    void *page[2];
};

#define pdev_to_cco(pdev) container_of((pdev), struct cco_device, pdev)
#define dev_to_cco(dev) container_of((dev), struct cco_device, pdev.dev)

// Driver management
int cco_register_driver(void);
void cco_unregister_driver(void);

// Device discovery
int cco_device_discovery_init(void);
void cco_device_discovery_exit(void);
void handle_session_ctl_msg(struct sk_buff *skb);

// Device management
void cco_unregister_devices(void);

#endif
