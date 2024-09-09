#ifndef CCO_PCM_H
#define CCO_PCM_H

#include <sound/core.h>
#include <sound/pcm.h>

#include "device.h"

#define MAX_PCM_DEVICES    4
#define MAX_PCM_SUBSTREAMS 128

#define MAX_BUFFER_SIZE  (64*1024)
#define MIN_PERIOD_SIZE  64
#define MAX_PERIOD_SIZE  MAX_BUFFER_SIZE
#define USE_FORMATS      (SNDRV_PCM_FMTBIT_U8 | SNDRV_PCM_FMTBIT_S16_LE)
#define USE_RATE         SNDRV_PCM_RATE_CONTINUOUS | SNDRV_PCM_RATE_8000_48000
#define USE_RATE_MIN     5500
#define USE_RATE_MAX     48000
#define USE_CHANNELS_MIN 1
#define USE_CHANNELS_MAX 2
#define USE_PERIODS_MIN  1
#define USE_PERIODS_MAX  1024
static const struct snd_pcm_hardware dummy_pcm_hardware = {
    .info             = ( SNDRV_PCM_INFO_MMAP
                        | SNDRV_PCM_INFO_INTERLEAVED
                        | SNDRV_PCM_INFO_RESUME
                        | SNDRV_PCM_INFO_MMAP_VALID ),
    .formats          = USE_FORMATS,
    .rates            = USE_RATE,
    .rate_min         = USE_RATE_MIN,
    .rate_max         = USE_RATE_MAX,
    .channels_min     = USE_CHANNELS_MIN,
    .channels_max     = USE_CHANNELS_MAX,
    .buffer_bytes_max = MAX_BUFFER_SIZE,
    .period_bytes_min = MIN_PERIOD_SIZE,
    .period_bytes_max = MAX_PERIOD_SIZE,
    .periods_min      = USE_PERIODS_MIN,
    .periods_max      = USE_PERIODS_MAX,
    .fifo_size        = 0,
};

void free_fake_buffer(void);
int alloc_fake_buffer(void);

struct snd_dummy;
int snd_card_dummy_pcm(struct snd_dummy *dummy, int device, int substreams);

#endif
