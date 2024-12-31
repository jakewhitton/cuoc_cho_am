#ifndef CCO_DEVICE_H
#define CCO_DEVICE_H

#include <linux/kthread.h>
#include <linux/platform_device.h>
#include <linux/skbuff.h>
#include <linux/timekeeping.h>
#include <sound/core.h>

#include "mixer.h"
#include "pcm.h"

struct cco_device {
    struct platform_device pdev;
    struct snd_card *card;

    struct task_struct *pcm_manager_task;
    struct cco_pcm playback;
    struct cco_pcm capture;

    struct cco_mixer mixer;

    struct cco_session *session;
};

struct cco_session {
    struct cco_device *dev;
    int id;
    unsigned char mac[ETH_ALEN];
    uint8_t generation_id;
    ktime_t ts_last_recv;
    ktime_t ts_last_send;
};

#define pdev_to_cco(pdev) container_of((pdev), struct cco_device, pdev)
#define dev_to_cco(dev) container_of((dev), struct cco_device, pdev.dev)

// Driver management
int cco_register_driver(void);
void cco_unregister_driver(void);

// Session management
struct cco_session *cco_get_session(unsigned char *mac, uint8_t generation_id);
void cco_close_sessions(void);
int cco_session_manager_init(void);
void cco_session_manager_exit(void);

#endif
