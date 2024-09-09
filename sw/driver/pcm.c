#include "pcm.h"
#include "timer.h"

static void *dummy_page[2];

/*================================PCM interface===============================*/
static int dummy_pcm_open(struct snd_pcm_substream *substream)
{
    struct snd_dummy *dummy = snd_pcm_substream_chip(substream);
    struct snd_pcm_runtime *runtime = substream->runtime;
    const struct dummy_timer_ops *ops;
    int err;

    ops = &dummy_systimer_ops;

    err = ops->create(substream);
    if (err < 0)
        return err;
    get_dummy_ops(substream) = ops;

    runtime->hw = dummy->pcm_hw;
    if (substream->pcm->device & 1) {
        runtime->hw.info &= ~SNDRV_PCM_INFO_INTERLEAVED;
        runtime->hw.info |= SNDRV_PCM_INFO_NONINTERLEAVED;
    }
    if (substream->pcm->device & 2)
        runtime->hw.info &= ~(SNDRV_PCM_INFO_MMAP |
                      SNDRV_PCM_INFO_MMAP_VALID);

    return 0;
}

static int dummy_pcm_close(struct snd_pcm_substream *substream)
{
    get_dummy_ops(substream)->free(substream);
    return 0;
}

static int dummy_pcm_hw_params(struct snd_pcm_substream *substream,
                   struct snd_pcm_hw_params *hw_params)
{
    if (fake_buffer) {
        /* runtime->dma_bytes has to be set manually to allow mmap */
        substream->runtime->dma_bytes = params_buffer_bytes(hw_params);
        return 0;
    }
    return 0;
}

static int dummy_pcm_prepare(struct snd_pcm_substream *substream)
{
    return get_dummy_ops(substream)->prepare(substream);
}

static int dummy_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
    switch (cmd) {
    case SNDRV_PCM_TRIGGER_START:
    case SNDRV_PCM_TRIGGER_RESUME:
        return get_dummy_ops(substream)->start(substream);
    case SNDRV_PCM_TRIGGER_STOP:
    case SNDRV_PCM_TRIGGER_SUSPEND:
        return get_dummy_ops(substream)->stop(substream);
    }
    return -EINVAL;
}

static snd_pcm_uframes_t dummy_pcm_pointer(struct snd_pcm_substream *substream)
{
    return get_dummy_ops(substream)->pointer(substream);
}

static int dummy_pcm_copy(struct snd_pcm_substream *substream,
              int channel, unsigned long pos,
              struct iov_iter *iter, unsigned long bytes)
{
    return 0; /* do nothing */
}

static int dummy_pcm_silence(struct snd_pcm_substream *substream,
                 int channel, unsigned long pos,
                 unsigned long bytes)
{
    return 0; /* do nothing */
}

static struct page *dummy_pcm_page(struct snd_pcm_substream *substream,
                   unsigned long offset)
{
    return virt_to_page(dummy_page[substream->stream]); /* the same page */
}

static const struct snd_pcm_ops dummy_pcm_ops = {
    .open      = dummy_pcm_open,
    .close     = dummy_pcm_close,
    .hw_params = dummy_pcm_hw_params,
    .prepare   = dummy_pcm_prepare,
    .trigger   = dummy_pcm_trigger,
    .pointer   = dummy_pcm_pointer,
};

static const struct snd_pcm_ops dummy_pcm_ops_no_buf = {
    .open         = dummy_pcm_open,
    .close        = dummy_pcm_close,
    .hw_params    = dummy_pcm_hw_params,
    .prepare      = dummy_pcm_prepare,
    .trigger      = dummy_pcm_trigger,
    .pointer      = dummy_pcm_pointer,
    // Unique to dummy_pcm_ops_no_buf
    .copy         = dummy_pcm_copy,
    .fill_silence = dummy_pcm_silence,
    .page         = dummy_pcm_page,
};
/*============================================================================*/


/*===============================Initialization===============================*/
void free_fake_buffer(void)
{
    if (fake_buffer) {
        int i;
        for (i = 0; i < 2; i++)
            if (dummy_page[i]) {
                free_page((unsigned long)dummy_page[i]);
                dummy_page[i] = NULL;
            }
    }
}

int alloc_fake_buffer(void)
{
    int i;

    if (!fake_buffer)
        return 0;
    for (i = 0; i < 2; i++) {
        dummy_page[i] = (void *)get_zeroed_page(GFP_KERNEL);
        if (!dummy_page[i]) {
            free_fake_buffer();
            return -ENOMEM;
        }
    }
    return 0;
}

int snd_card_dummy_pcm(struct snd_dummy *dummy, int device, int substreams)
{
    struct snd_pcm *pcm;
    const struct snd_pcm_ops *ops;
    int err;

    err = snd_pcm_new(dummy->card, "Dummy PCM", device,
                      substreams /* playback_count */,
                      substreams /* capture_count */,
                      &pcm);
    if (err < 0)
        return err;
    dummy->pcm = pcm;
    if (fake_buffer)
        ops = &dummy_pcm_ops_no_buf;
    else
        ops = &dummy_pcm_ops;
    snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, ops);
    snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, ops);
    pcm->private_data = dummy;
    pcm->info_flags = 0;
    strcpy(pcm->name, "Dummy PCM");
    if (!fake_buffer) {
        snd_pcm_set_managed_buffer_all(pcm,
            SNDRV_DMA_TYPE_CONTINUOUS,
            NULL,
            0, 64*1024);
    }
    return 0;
}
/*============================================================================*/
