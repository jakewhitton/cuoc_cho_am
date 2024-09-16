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
static void cco_systimer_rearm(struct cco_systimer_pcm *pcm);
static void cco_systimer_update(struct cco_systimer_pcm *pcm);

/*===========================System timer interface===========================*/
static int cco_systimer_create(struct snd_pcm_substream *substream)
{
    int err;

    struct cco_systimer_pcm *pcm;
    pcm = kzalloc(sizeof(*pcm), GFP_KERNEL);
    if (!pcm) {
        err = -ENOMEM;
        goto exit_error;
    }

    substream->runtime->private_data = pcm;
    timer_setup(&pcm->timer, cco_systimer_callback, 0);
    spin_lock_init(&pcm->lock);
    pcm->substream = substream;

    return 0;

exit_error:
    return err;
}

static void cco_systimer_free(struct snd_pcm_substream *substream)
{
    kfree(substream->runtime->private_data);
}

static int cco_systimer_prepare(struct snd_pcm_substream *substream)
{
    struct snd_pcm_runtime *runtime = substream->runtime;
    struct cco_systimer_pcm *pcm = runtime->private_data;

    pcm->frac_pos = 0;
    pcm->rate = runtime->rate;
    pcm->frac_buffer_size = runtime->buffer_size * HZ;
    pcm->frac_period_size = runtime->period_size * HZ;
    pcm->frac_period_rest = pcm->frac_period_size;
    pcm->elapsed = 0;

    return 0;
}

static int cco_systimer_start(struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *pcm = substream->runtime->private_data;

    spin_lock(&pcm->lock);
    pcm->base_time = jiffies;
    cco_systimer_rearm(pcm);
    spin_unlock(&pcm->lock);

    return 0;
}

static int cco_systimer_stop(struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *pcm = substream->runtime->private_data;

    spin_lock(&pcm->lock);
    del_timer(&pcm->timer);
    spin_unlock(&pcm->lock);

    return 0;
}

static snd_pcm_uframes_t cco_systimer_pointer(
    struct snd_pcm_substream *substream)
{
    struct cco_systimer_pcm *pcm = substream->runtime->private_data;
    snd_pcm_uframes_t pos;

    spin_lock(&pcm->lock);
    cco_systimer_update(pcm);
    pos = pcm->frac_pos / HZ;
    spin_unlock(&pcm->lock);

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
    struct cco_systimer_pcm *pcm = from_timer(pcm, t, timer);
    unsigned long flags;
    int elapsed = 0;

    spin_lock_irqsave(&pcm->lock, flags);
    cco_systimer_update(pcm);
    cco_systimer_rearm(pcm);
    elapsed = pcm->elapsed;
    pcm->elapsed = 0;
    spin_unlock_irqrestore(&pcm->lock, flags);

    if (elapsed)
        snd_pcm_period_elapsed(pcm->substream);
}

static void cco_systimer_rearm(struct cco_systimer_pcm *pcm)
{
    mod_timer(&pcm->timer, jiffies +
              DIV_ROUND_UP(pcm->frac_period_rest, pcm->rate));
}

static void cco_systimer_update(struct cco_systimer_pcm *pcm)
{
    unsigned long delta;

    delta = jiffies - pcm->base_time;
    if (!delta)
        return;

    pcm->base_time += delta;
    delta *= pcm->rate;
    pcm->frac_pos += delta;

    while (pcm->frac_pos >= pcm->frac_buffer_size) {
        pcm->frac_pos -= pcm->frac_buffer_size;
    }

    while (pcm->frac_period_rest <= delta) {
        pcm->elapsed++;
        pcm->frac_period_rest += pcm->frac_period_size;
    }

    pcm->frac_period_rest -= delta;
}
/*============================================================================*/
