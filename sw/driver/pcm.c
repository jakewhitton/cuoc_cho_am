#include "pcm.h"

#include <linux/slab.h>
#include <sound/core.h>
#include <sound/pcm.h>

#include "log.h"

/*===============================Initialization===============================*/
// Full definition is in "PCM interface" section
static const struct snd_pcm_ops cco_pcm_ops;

int cco_pcm_init(struct cco_device *cco)
{
    int err;

    for (int device = 0; device < PCM_DEVICES_PER_CARD; device++) {

        struct snd_pcm *pcm;
        err = snd_pcm_new(
            cco->card,                 /* snd_card instance */
            "CCO PCM",                 /* id */
            device,                    /* device number */
            PCM_SUBSTREAMS_PER_DEVICE, /* playback_count */
            PCM_SUBSTREAMS_PER_DEVICE, /* capture_count */
            &pcm);                     /* snd_pcm intance */
        if (err < 0) {
            printk(KERN_ERR "cco: snd_pcm_new() failed\n");
            goto exit_error;
        }
        pcm->info_flags = 0;
        strcpy(pcm->name, "CCO PCM");

        // Sound core will propagate to snd_pcm_substream->private_data
        pcm->private_data = cco;

        snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &cco_pcm_ops);
        snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &cco_pcm_ops);
    }

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}
/*============================================================================*/


/*================================PCM interface===============================*/
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

// State to be allocated per-substream
struct cco_pcm_impl {
    // Misc state
    spinlock_t lock;
    struct timer_list timer;
    struct snd_pcm_substream *substream;

    // Buffer state
    unsigned long base_time;
    unsigned int frac_pos;         /* fractional sample position (based HZ) */
    unsigned int frac_period_rest;
    unsigned int frac_buffer_size; /* buffer_size * HZ */
    unsigned int frac_period_size; /* period_size * HZ */
    unsigned int rate;
    int elapsed;
};

// Defined in "Timer handling" section
static void cco_pcm_timer_callback(struct timer_list *t);
static void cco_pcm_timer_rearm(struct cco_pcm_impl *impl);
static void cco_pcm_timer_update(struct cco_pcm_impl *impl);

static int cco_pcm_open(struct snd_pcm_substream *substream)
{
    int err;

    // Allocate and initialize state for handling newly created substream
    struct cco_pcm_impl *impl;
    impl = kzalloc(sizeof(*impl), GFP_KERNEL);
    if (!impl) {
        err = -ENOMEM;
        goto exit_error;
    }
    impl->substream = substream;
    spin_lock_init(&impl->lock);
    timer_setup(&impl->timer, cco_pcm_timer_callback, 0);

    struct snd_pcm_runtime *runtime = substream->runtime;
    runtime->private_data = impl;
    runtime->hw = cco_pcm_hardware;
    if (substream->pcm->device & 1) {
        runtime->hw.info &= ~SNDRV_PCM_INFO_INTERLEAVED;
        runtime->hw.info |= SNDRV_PCM_INFO_NONINTERLEAVED;
    }
    if (substream->pcm->device & 2)
        runtime->hw.info &= ~(SNDRV_PCM_INFO_MMAP | SNDRV_PCM_INFO_MMAP_VALID);

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int cco_pcm_close(struct snd_pcm_substream *substream)
{
    kfree(substream->runtime->private_data);
    return 0;
}

static int cco_pcm_hw_params(struct snd_pcm_substream *substream,
                             struct snd_pcm_hw_params *hw_params)
{
    /* runtime->dma_bytes has to be set manually to allow mmap */
    substream->runtime->dma_bytes = params_buffer_bytes(hw_params);
    return 0;
}

static int cco_pcm_prepare(struct snd_pcm_substream *substream)
{
    struct snd_pcm_runtime *runtime = substream->runtime;
    struct cco_pcm_impl *impl = runtime->private_data;

    impl->frac_pos = 0;
    impl->rate = runtime->rate;
    impl->frac_buffer_size = runtime->buffer_size * HZ;
    impl->frac_period_size = runtime->period_size * HZ;
    impl->frac_period_rest = impl->frac_period_size;
    impl->elapsed = 0;

    return 0;
}

static int cco_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
    int err;
    struct cco_pcm_impl *impl = substream->runtime->private_data;

    switch (cmd) {
        case SNDRV_PCM_TRIGGER_START:
        case SNDRV_PCM_TRIGGER_RESUME:
            spin_lock(&impl->lock);
            impl->base_time = jiffies;
            cco_pcm_timer_rearm(impl);
            spin_unlock(&impl->lock);
            break;


        case SNDRV_PCM_TRIGGER_STOP:
        case SNDRV_PCM_TRIGGER_SUSPEND:

            spin_lock(&impl->lock);
            del_timer(&impl->timer);
            spin_unlock(&impl->lock);
            break;

        default:
            err = -EINVAL;
            goto exit_error;
    }

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static snd_pcm_uframes_t cco_pcm_pointer(struct snd_pcm_substream *substream)
{
    snd_pcm_uframes_t pos;
    struct cco_pcm_impl *impl = substream->runtime->private_data;

    spin_lock(&impl->lock);
    cco_pcm_timer_update(impl);
    pos = impl->frac_pos / HZ;
    spin_unlock(&impl->lock);

    return pos;
}

static int cco_pcm_silence(struct snd_pcm_substream *substream,
                           int channel, unsigned long pos,
                           unsigned long bytes)
{
    return 0; /* do nothing */
}

static int cco_pcm_copy(struct snd_pcm_substream *substream,
                        int channel, unsigned long pos,
                        struct iov_iter *iter, unsigned long bytes)
{
    return 0; /* do nothing */
}

static struct page *cco_pcm_page(struct snd_pcm_substream *substream,
                                 unsigned long offset)
{
    struct cco_device *cco = substream->private_data;
    return virt_to_page(cco->page[substream->stream]); /* the same page */
}

static const struct snd_pcm_ops cco_pcm_ops = {
    .open         = cco_pcm_open,
    .close        = cco_pcm_close,
    .hw_params    = cco_pcm_hw_params,
    .prepare      = cco_pcm_prepare,
    .trigger      = cco_pcm_trigger,
    .pointer      = cco_pcm_pointer,
    .fill_silence = cco_pcm_silence,
    .copy         = cco_pcm_copy,
    .page         = cco_pcm_page,
};
/*============================================================================*/


/*===============================Timer handling===============================*/
static void cco_pcm_timer_callback(struct timer_list *t)
{
    struct cco_pcm_impl *impl = from_timer(impl, t, timer);
    unsigned long flags;
    int elapsed = 0;

    spin_lock_irqsave(&impl->lock, flags);
    cco_pcm_timer_update(impl);
    cco_pcm_timer_rearm(impl);
    elapsed = impl->elapsed;
    impl->elapsed = 0;
    spin_unlock_irqrestore(&impl->lock, flags);

    if (elapsed)
        snd_pcm_period_elapsed(impl->substream);
}

static void cco_pcm_timer_rearm(struct cco_pcm_impl *impl)
{
    mod_timer(&impl->timer, jiffies +
              DIV_ROUND_UP(impl->frac_period_rest, impl->rate));
}

static void cco_pcm_timer_update(struct cco_pcm_impl *impl)
{
    unsigned long delta;

    delta = jiffies - impl->base_time;
    if (!delta)
        return;

    impl->base_time += delta;
    delta *= impl->rate;
    impl->frac_pos += delta;

    while (impl->frac_pos >= impl->frac_buffer_size) {
        impl->frac_pos -= impl->frac_buffer_size;
    }

    while (impl->frac_period_rest <= delta) {
        impl->elapsed++;
        impl->frac_period_rest += impl->frac_period_size;
    }

    impl->frac_period_rest -= delta;
}
/*============================================================================*/
