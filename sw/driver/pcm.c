#include "pcm.h"

#include "log.h"
#include "timer.h"

static void *page[2];

/*================================PCM interface===============================*/
static int cco_pcm_open(struct snd_pcm_substream *substream)
{
    int err;

    const struct cco_timer_ops *ops = &cco_systimer_ops;
    err = ops->create(substream);
    if (err < 0)
        goto exit_error;
    get_cco_ops(substream) = ops;

    struct snd_pcm_runtime *runtime = substream->runtime;
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
    get_cco_ops(substream)->free(substream);
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
    return get_cco_ops(substream)->prepare(substream);
}

static int cco_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
    switch (cmd) {
        case SNDRV_PCM_TRIGGER_START:
        case SNDRV_PCM_TRIGGER_RESUME:
            return get_cco_ops(substream)->start(substream);
        case SNDRV_PCM_TRIGGER_STOP:
        case SNDRV_PCM_TRIGGER_SUSPEND:
            return get_cco_ops(substream)->stop(substream);
    }

    return -EINVAL;
}

static snd_pcm_uframes_t cco_pcm_pointer(struct snd_pcm_substream *substream)
{
    return get_cco_ops(substream)->pointer(substream);
}

static int cco_pcm_copy(struct snd_pcm_substream *substream,
                        int channel, unsigned long pos,
                        struct iov_iter *iter, unsigned long bytes)
{
    return 0; /* do nothing */
}

static int cco_pcm_silence(struct snd_pcm_substream *substream,
                           int channel, unsigned long pos,
                           unsigned long bytes)
{
    return 0; /* do nothing */
}

static struct page *cco_pcm_page(struct snd_pcm_substream *substream,
                                 unsigned long offset)
{
    return virt_to_page(page[substream->stream]); /* the same page */
}

static const struct snd_pcm_ops cco_pcm_ops = {
    .open         = cco_pcm_open,
    .close        = cco_pcm_close,
    .hw_params    = cco_pcm_hw_params,
    .prepare      = cco_pcm_prepare,
    .trigger      = cco_pcm_trigger,
    .pointer      = cco_pcm_pointer,
    .copy         = cco_pcm_copy,
    .fill_silence = cco_pcm_silence,
    .page         = cco_pcm_page,
};
/*============================================================================*/


/*===============================Initialization===============================*/
int alloc_fake_buffer(void)
{
    int err;

    for (int i = 0; i < ARRAY_SIZE(page); i++) {
        page[i] = (void *)get_zeroed_page(GFP_KERNEL);
        if (!page[i]) {
            err = -ENOMEM;
            goto undo_alloc;
        }
    }

    return 0;

undo_alloc:
    free_fake_buffer();
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void free_fake_buffer(void)
{
    for (int i = 0; i < ARRAY_SIZE(page); i++) {
        if (page[i]) {
            free_page((unsigned long)page[i]);
            page[i] = NULL;
        }
    }
}

int cco_pcm_init(struct cco_device *cco, int device, int substreams)
{
    int err;

    struct snd_pcm *pcm;
    err = snd_pcm_new(
        cco->card, /* snd_card instance */
        "CCO PCM", /* id */
        device,    /* device number */
        substreams /* playback_count */,
        substreams /* capture_count */,
        &pcm);     /* pcm intance */
    if (err < 0) {
        printk(KERN_ERR "cco: snd_pcm_new() failed\n");
        goto exit_error;
    }

    pcm->info_flags = 0;
    strcpy(pcm->name, "CCO PCM");
    pcm->private_data = cco;

    snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &cco_pcm_ops);
    snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &cco_pcm_ops);

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}
/*============================================================================*/
