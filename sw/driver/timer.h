#ifndef CCO_TIMER_H
#define CCO_TIMER_H

#include <sound/pcm.h>

struct cco_timer_ops {
    int (*create)(struct snd_pcm_substream *);
    void (*free)(struct snd_pcm_substream *);
    int (*prepare)(struct snd_pcm_substream *);
    int (*start)(struct snd_pcm_substream *);
    int (*stop)(struct snd_pcm_substream *);
    snd_pcm_uframes_t (*pointer)(struct snd_pcm_substream *);
};

#define get_cco_ops(substream) \
    (*(const struct cco_timer_ops **)(substream)->runtime->private_data)

extern const struct cco_timer_ops cco_systimer_ops;

#endif
