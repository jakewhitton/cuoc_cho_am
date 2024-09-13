#ifndef CCO_PCM_H
#define CCO_PCM_H

#include <sound/core.h>
#include <sound/pcm.h>

#include "device.h"

#define PCM_DEVICES_PER_CARD      1
#define PCM_SUBSTREAMS_PER_DEVICE 2

static const struct snd_pcm_hardware cco_pcm_hardware = {
    // General info
    .info             = ( SNDRV_PCM_INFO_MMAP
                        | SNDRV_PCM_INFO_INTERLEAVED
                        | SNDRV_PCM_INFO_RESUME
                        | SNDRV_PCM_INFO_MMAP_VALID ),

    // Sample format
    .formats          = ( SNDRV_PCM_FMTBIT_U8
                        | SNDRV_PCM_FMTBIT_S16_LE),

    // Sampling rate
    .rates            = ( SNDRV_PCM_RATE_CONTINUOUS
                        | SNDRV_PCM_RATE_8000_48000 ),
    .rate_min         = 5500,
    .rate_max         = 48000,

    // Channels
    .channels_min     = 1,
    .channels_max     = 2,

    // Buffer params
    .buffer_bytes_max = 64*1024,
    .period_bytes_min = 64,
    .period_bytes_max = 64*1024,
    .periods_min      = 1,
    .periods_max      = 1024,
    .fifo_size        = 0,
};

void free_fake_buffer(void);
int alloc_fake_buffer(void);

struct cco_device;
int cco_pcm_init(struct cco_device *cco, int device, int substreams);

#endif
