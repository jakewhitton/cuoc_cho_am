#include "timer.h"

struct cco_systimer_pcm {
    /* ops must be the first item */
    const struct cco_timer_ops *timer_ops;
    spinlock_t lock;
    struct timer_list timer;
    unsigned long base_time;
    unsigned int frac_pos;         /* fractional sample position (based HZ) */
    unsigned int frac_period_rest;
    unsigned int frac_buffer_size; /* buffer_size * HZ */
    unsigned int frac_period_size; /* period_size * HZ */
    unsigned int rate;
    int elapsed;
    struct snd_pcm_substream *substream;
};

// Helpers
static void cco_systimer_callback(struct timer_list *t);
static void cco_systimer_rearm(struct cco_systimer_pcm *dpcm);
static void cco_systimer_update(struct cco_systimer_pcm *dpcm);

/*===========================System timer interface===========================*/
static int cco_systimer_create(struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *dpcm;

    dpcm = kzalloc(sizeof(*dpcm), GFP_KERNEL);
    if (!dpcm)
        return -ENOMEM;
    substream->runtime->private_data = dpcm;
    timer_setup(&dpcm->timer, cco_systimer_callback, 0);
    spin_lock_init(&dpcm->lock);
    dpcm->substream = substream;
    return 0;
}

static void cco_systimer_free(struct snd_pcm_substream *substream)
{
    kfree(substream->runtime->private_data);
}

static int cco_systimer_prepare(struct snd_pcm_substream *substream)
{
    struct snd_pcm_runtime *runtime = substream->runtime;
    struct cco_systimer_pcm *dpcm = runtime->private_data;

    dpcm->frac_pos = 0;
    dpcm->rate = runtime->rate;
    dpcm->frac_buffer_size = runtime->buffer_size * HZ;
    dpcm->frac_period_size = runtime->period_size * HZ;
    dpcm->frac_period_rest = dpcm->frac_period_size;
    dpcm->elapsed = 0;

    return 0;
}

static int cco_systimer_start(struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *dpcm = substream->runtime->private_data;
    spin_lock(&dpcm->lock);
    dpcm->base_time = jiffies;
    cco_systimer_rearm(dpcm);
    spin_unlock(&dpcm->lock);
    return 0;
}

static int cco_systimer_stop(struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *dpcm = substream->runtime->private_data;
    spin_lock(&dpcm->lock);
    del_timer(&dpcm->timer);
    spin_unlock(&dpcm->lock);
    return 0;
}

static snd_pcm_uframes_t cco_systimer_pointer(
	struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *dpcm = substream->runtime->private_data;
    snd_pcm_uframes_t pos;

    spin_lock(&dpcm->lock);
    cco_systimer_update(dpcm);
    pos = dpcm->frac_pos / HZ;
    spin_unlock(&dpcm->lock);
    return pos;
}

const struct cco_timer_ops cco_systimer_ops = {
    .create  = cco_systimer_create,
    .free    = cco_systimer_free,
    .prepare = cco_systimer_prepare,
    .start   = cco_systimer_start,
    .stop    = cco_systimer_stop,
    .pointer = cco_systimer_pointer,
};
/*============================================================================*/


/*==================================Helpers===================================*/
static void cco_systimer_callback(struct timer_list *t)
{
    struct cco_systimer_pcm *dpcm = from_timer(dpcm, t, timer);
    unsigned long flags;
    int elapsed = 0;

    spin_lock_irqsave(&dpcm->lock, flags);
    cco_systimer_update(dpcm);
    cco_systimer_rearm(dpcm);
    elapsed = dpcm->elapsed;
    dpcm->elapsed = 0;
    spin_unlock_irqrestore(&dpcm->lock, flags);
    if (elapsed)
        snd_pcm_period_elapsed(dpcm->substream);
}

static void cco_systimer_rearm(struct cco_systimer_pcm *dpcm)
{
    mod_timer(&dpcm->timer, jiffies +
        DIV_ROUND_UP(dpcm->frac_period_rest, dpcm->rate));
}

static void cco_systimer_update(struct cco_systimer_pcm *dpcm)
{
    unsigned long delta;

    delta = jiffies - dpcm->base_time;
    if (!delta)
        return;
    dpcm->base_time += delta;
    delta *= dpcm->rate;
    dpcm->frac_pos += delta;
    while (dpcm->frac_pos >= dpcm->frac_buffer_size)
        dpcm->frac_pos -= dpcm->frac_buffer_size;
    while (dpcm->frac_period_rest <= delta) {
        dpcm->elapsed++;
        dpcm->frac_period_rest += dpcm->frac_period_size;
    }
    dpcm->frac_period_rest -= delta;
}
/*============================================================================*/
