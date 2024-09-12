#ifndef CCO_MIXER_H
#define CCO_MIXER_H

#define MIXER_VOLUME_LEVEL_MIN -50
#define MIXER_VOLUME_LEVEL_MAX 100

#define MIXER_ADDR_MASTER 0
#define MIXER_ADDR_LINE   1
#define MIXER_ADDR_MIC    2
#define MIXER_ADDR_SYNTH  3
#define MIXER_ADDR_CD     4
#define MIXER_ADDR_LAST   4

struct cco_device;
int cco_mixer_init(struct cco_device *cco);

#endif
