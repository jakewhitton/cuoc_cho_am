#ifndef CCO_PCM_H
#define CCO_PCM_H

#include <linux/list.h>

#include "protocol.h"

struct cco_device;

struct cco_pcm {
    struct snd_pcm *pcm;
    struct list_head periods;
    struct list_head *cursors[CHANNELS_PER_PACKET];
    uint32_t seqnum;

    struct cco_device *dev;
};

// Initialization
int cco_pcm_init(struct cco_device *cco);
void cco_pcm_exit(struct cco_device *cco);

#endif
