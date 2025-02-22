#ifndef CCO_PCM_H
#define CCO_PCM_H

#include <linux/list.h>

#include "protocol.h"

struct cco_device;

struct cco_pcm {
    struct snd_pcm *pcm;
    struct snd_pcm_substream *substream;

    struct list_head periods;
    struct list_head *cursors[CHANNELS_PER_PACKET];
    uint32_t seqnum;
    bool active;

    // Only used for capture
    int p;

    struct cco_device *dev;
};

// Initialization
int cco_pcm_init(struct cco_device *cco);
void cco_pcm_exit(struct cco_device *cco);

// Period management
int cco_pcm_put_period(struct cco_pcm *pcm, struct sk_buff *skb);

#endif
