#ifndef CCO_MIXER_H
#define CCO_MIXER_H

#define USE_MIXER_VOLUME_LEVEL_MIN -50
#define USE_MIXER_VOLUME_LEVEL_MAX 100

#define MIXER_ADDR_MASTER 0
#define MIXER_ADDR_LINE   1
#define MIXER_ADDR_MIC    2
#define MIXER_ADDR_SYNTH  3
#define MIXER_ADDR_CD     4
#define MIXER_ADDR_LAST   4

struct snd_dummy;
int snd_card_dummy_new_mixer(struct snd_dummy *dummy);

#endif
