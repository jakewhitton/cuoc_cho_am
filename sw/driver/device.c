#include "device.h"

#include <sound/initval.h>

int   index         [SNDRV_CARDS] = SNDRV_DEFAULT_IDX;    /* Index 0-MAX */
char *id            [SNDRV_CARDS] = SNDRV_DEFAULT_STR;    /* ID for this card */
bool  enable        [SNDRV_CARDS] = {1, [1 ... (SNDRV_CARDS - 1)] = 0};
int   pcm_devs      [SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 1};
int   pcm_substreams[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 8};
int   mixer_volume_level_min      = USE_MIXER_VOLUME_LEVEL_MIN;
int   mixer_volume_level_max      = USE_MIXER_VOLUME_LEVEL_MAX;
bool  fake_buffer                 = 1;

struct platform_device *devices[SNDRV_CARDS];
