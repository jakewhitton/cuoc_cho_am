#ifndef CCO_PCM_H
#define CCO_PCM_H

#include "device.h"

int alloc_fake_buffer(void);
void free_fake_buffer(void);

int cco_pcm_init(struct cco_device *cco);

#endif
