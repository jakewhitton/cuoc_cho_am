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

static int snd_dummy_probe(struct platform_device *devptr)
{
    struct snd_card *card;
    struct snd_dummy *dummy;
    int idx, err;
    int dev = devptr->id;

    err = snd_devm_card_new(&devptr->dev, index[dev], id[dev], THIS_MODULE,
                sizeof(struct snd_dummy), &card);
    if (err < 0)
        return err;
    dummy = card->private_data;
    dummy->card = card;

    for (idx = 0; idx < MAX_PCM_DEVICES && idx < pcm_devs[dev]; idx++) {
        if (pcm_substreams[dev] < 1)
            pcm_substreams[dev] = 1;
        if (pcm_substreams[dev] > MAX_PCM_SUBSTREAMS)
            pcm_substreams[dev] = MAX_PCM_SUBSTREAMS;
        err = snd_card_dummy_pcm(dummy, idx, pcm_substreams[dev]);
        if (err < 0)
            return err;
    }

    dummy->pcm_hw = dummy_pcm_hardware;

    if (mixer_volume_level_min > mixer_volume_level_max) {
        pr_warn("snd-dummy: Invalid mixer volume level: min=%d, max=%d. Fall back to default value.\n",
        mixer_volume_level_min, mixer_volume_level_max);
        mixer_volume_level_min = USE_MIXER_VOLUME_LEVEL_MIN;
        mixer_volume_level_max = USE_MIXER_VOLUME_LEVEL_MAX;
    }
    err = snd_card_dummy_new_mixer(dummy);
    if (err < 0)
        return err;
    strcpy(card->driver, "Dummy");
    strcpy(card->shortname, "Dummy");
    sprintf(card->longname, "Dummy %i", dev + 1);

    err = snd_card_register(card);
    if (err < 0)
        return err;
    platform_set_drvdata(devptr, card);
    return 0;
}

static int snd_dummy_suspend(struct device *pdev)
{
    struct snd_card *card = dev_get_drvdata(pdev);

    snd_power_change_state(card, SNDRV_CTL_POWER_D3hot);
    return 0;
}

static int snd_dummy_resume(struct device *pdev)
{
    struct snd_card *card = dev_get_drvdata(pdev);

    snd_power_change_state(card, SNDRV_CTL_POWER_D0);
    return 0;
}

static DEFINE_SIMPLE_DEV_PM_OPS(snd_dummy_pm, snd_dummy_suspend, snd_dummy_resume);

#define SND_DUMMY_DRIVER    "snd_dummy"

static struct platform_driver snd_dummy_driver = {
    .probe  = snd_dummy_probe,
    .driver = {
        .name = SND_DUMMY_DRIVER,
        .pm   = &snd_dummy_pm,
    },
};

int snd_dummy_register_all(void)
{
    int i, cards, err;

    err = platform_driver_register(&snd_dummy_driver);
    if (err < 0)
        return err;

    err = alloc_fake_buffer();
    if (err < 0) {
        platform_driver_unregister(&snd_dummy_driver);
        return err;
    }

    cards = 0;
    for (i = 0; i < SNDRV_CARDS; i++) {
        struct platform_device *device;
        if (! enable[i])
            continue;

        // Register platform device, which will cause probe()
        // method to be called if name supplied matches that of
        // driver that was previously registered
        device = platform_device_register_simple(SND_DUMMY_DRIVER,
                             i, NULL, 0);
        if (IS_ERR(device))
            continue;

        if (!platform_get_drvdata(device)) {
            platform_device_unregister(device);
            continue;
        }

        devices[i] = device;
        cards++;
    }
    if (!cards) {
#ifdef MODULE
        printk(KERN_ERR "Dummy soundcard not found or device busy\n");
#endif
        snd_dummy_unregister_all();
        return -ENODEV;
    }
    return 0;
}

void snd_dummy_unregister_all(void)
{
    int i;

    for (i = 0; i < ARRAY_SIZE(devices); ++i)
        platform_device_unregister(devices[i]);
    platform_driver_unregister(&snd_dummy_driver);
    free_fake_buffer();
}
