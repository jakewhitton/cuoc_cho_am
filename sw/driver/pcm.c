#include "pcm.h"

#include <linux/delay.h>
#include <linux/skbuff.h>
#include <linux/slab.h>
#include <linux/timekeeping.h>
#include <sound/core.h>
#include <sound/pcm.h>

#include "device.h"
#include "ethernet.h"
#include "log.h"
#include "protocol.h"

/*===============================Initialization===============================*/
// Full definition is in "PCM <-> Ethernet" section
static int pcm_manager(void * data);

// Full definition is in "PCM interface" section
static const struct snd_pcm_ops cco_pcm_ops;

static int cco_pcm_device_init(struct cco_pcm *pcm, struct cco_device *dev,
                               int id, const char *name, bool is_playback)
{
    int err;

    int playback_substreams, capture_substreams;
    if (is_playback) {
        playback_substreams = 1;
        capture_substreams = 0;
    } else {
        playback_substreams = 0;
        capture_substreams = 1;
    }

    // Set up pcm device
    struct snd_pcm *pcm_tmp;
    err = snd_pcm_new(
        dev->card,           /* snd_card instance */
        name,                /* name */
        id,                  /* device number */
        playback_substreams, /* playback_count */
        capture_substreams,  /* capture_count */
        &pcm_tmp);           /* snd_pcm intance */
    if (err < 0) {
        printk(KERN_ERR "cco: snd_pcm_new() failed\n");
        goto exit_error;
    }
    pcm_tmp->info_flags = 0;
    strcpy(pcm_tmp->name, name);

    // Sound core will propagate to snd_pcm_substream->private_data
    pcm_tmp->private_data = dev;

    if (is_playback) {
        snd_pcm_set_ops(pcm_tmp, SNDRV_PCM_STREAM_PLAYBACK, &cco_pcm_ops);
    } else {
        snd_pcm_set_ops(pcm_tmp, SNDRV_PCM_STREAM_CAPTURE, &cco_pcm_ops);
    }

    pcm->pcm = pcm_tmp;

    INIT_LIST_HEAD(&pcm->periods);

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static void cco_pcm_device_exit(struct cco_pcm *pcm)
{
    struct cco_device *dev = pcm->pcm->private_data;

    if (pcm->pcm) {
        snd_device_free(dev->card, pcm->pcm);
        pcm->pcm = NULL;
    }
}

int cco_pcm_init(struct cco_device *cco)
{
    int err;

    // Boot infrastructure for transporting PCM data to and from ethernet
    struct task_struct *task;
    task = kthread_run(pcm_manager, cco, "cco_pcm_manager");
    if (IS_ERR(task)) {
        printk(KERN_ERR "cco: pcm manager kthread could not be created\n");
        err = -EAGAIN;
        goto exit_error;
    }
    cco->pcm_manager_task = task;

    // Set up playback device
    err = cco_pcm_device_init(&cco->playback, cco, 0, "CCO out", true);
    if (err < 0) {
        printk(KERN_ERR "cco: failed to create playback device\n");
        goto exit_error;
    }

    // Set up capture device
    err = cco_pcm_device_init(&cco->capture, cco, 1, "CCO in", false);
    if (err < 0) {
        printk(KERN_ERR "cco: failed to create capture device\n");
        goto exit_error;
    }

    return 0;

exit_error:
    cco_pcm_exit(cco);
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_pcm_exit(struct cco_device *cco)
{
    if (cco->pcm_manager_task) {
        if (kthread_stop(cco->pcm_manager_task) < 0)
            printk(KERN_ERR "cco: could not stop pcm manager kthread\n");
        cco->pcm_manager_task = NULL;
    }

    cco_pcm_device_exit(&cco->playback);

    cco_pcm_device_exit(&cco->capture);
}
/*============================================================================*/


/*==============================Buffer Management=============================*/
struct cco_pcm_period {
    struct sk_buff *skb;
    struct list_head list;
};

static int cco_pcm_put_period(struct cco_pcm *pcm, struct sk_buff *skb)
{
    // TODO
    return 0;
}

static int cco_pcm_get_period(struct cco_pcm *pcm, struct sk_buff **result)
{
    // TODO
    return 0;
}

static int cco_pcm_put_samples(struct cco_pcm *pcm, int channel,
                               struct iov_iter *iter, unsigned long bytes)
{
    // TODO
    return 0;
}

static int cco_pcm_get_samples(struct cco_pcm *pcm, int channel,
                               struct iov_iter *iter, unsigned long bytes)
{
    // TODO
    return 0;
}
/*============================================================================*/


/*================================PCM interface===============================*/
static const struct snd_pcm_hardware cco_pcm_hardware = {
    // General info
    .info             = SNDRV_PCM_INFO_NONINTERLEAVED,

    // Sample format
    .formats          = SNDRV_PCM_FMTBIT_S24_BE,

    // Sampling rate
    .rates            = SNDRV_PCM_RATE_48000,
    .rate_min         = 48000,
    .rate_max         = 48000,

    // Channels
    .channels_min     = 2,
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

    struct cco_device *dev = snd_pcm_substream_chip(substream);
    struct cco_session *session = dev->session;

    switch (cmd) {
        case SNDRV_PCM_TRIGGER_START:
        case SNDRV_PCM_TRIGGER_RESUME:

            // Notify FPGA that stream should begin
            send_pcm_ctl(session, PCM_CTL_START);

            spin_lock(&impl->lock);
            impl->base_time = jiffies;
            cco_pcm_timer_rearm(impl);
            spin_unlock(&impl->lock);
            break;


        case SNDRV_PCM_TRIGGER_STOP:
        case SNDRV_PCM_TRIGGER_SUSPEND:

            // Notify FPGA that stream should begin
            send_pcm_ctl(session, PCM_CTL_STOP);

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
    int err;

    struct cco_device *dev = snd_pcm_substream_chip(substream);

    if (iov_iter_rw(iter) == WRITE) {
        err = cco_pcm_put_samples(&dev->playback, channel, iter, bytes);
    } else {
        err = cco_pcm_get_samples(&dev->capture, channel, iter, bytes);
    }

    if (err < 0)
        goto exit_error;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
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


/*==============================PCM <-> Ethernet==============================*/
static int pcm_manager(void * data)
{
    struct cco_device *dev = (struct cco_device *)data;

    while (!kthread_should_stop()) {

        struct list_head *pos;

        unsigned playback_periods = 0;
        list_for_each(pos, &dev->playback.periods) {
            ++playback_periods;
        }

        unsigned capture_periods = 0;
        list_for_each(pos, &dev->capture.periods) {
            ++capture_periods;
        }

        printk(KERN_INFO "[playback: %u, capture: %u]\n",
               playback_periods, capture_periods);

        msleep(1000);
    }

    return 0;
}
/*============================================================================*/
