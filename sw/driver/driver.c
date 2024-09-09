#include <linux/init.h>
#include <linux/err.h>
#include <linux/platform_device.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/time.h>
#include <linux/wait.h>
#include <linux/hrtimer.h>
#include <linux/math64.h>
#include <linux/module.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/tlv.h>
#include <sound/pcm.h>
#include <sound/info.h>
#include <sound/initval.h>

#include "pcm.h"
#include "timer.h"
#include "device.h"
#include "mixer.h"

MODULE_AUTHOR("Jaroslav Kysela <perex@perex.cz>");
MODULE_DESCRIPTION("Dummy soundcard (/dev/null)");
MODULE_LICENSE("GPL");

#define MAX_PCM_DEVICES    4
#define MAX_PCM_SUBSTREAMS 128

/* defaults */

module_param_array(index, int, NULL, 0444);
MODULE_PARM_DESC(index, "Index value for dummy soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for dummy soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this dummy soundcard.");
module_param_array(pcm_devs, int, NULL, 0444);
MODULE_PARM_DESC(pcm_devs, "PCM devices # (0-4) for dummy driver.");
module_param_array(pcm_substreams, int, NULL, 0444);
MODULE_PARM_DESC(pcm_substreams, "PCM substreams # (1-128) for dummy driver.");
module_param(mixer_volume_level_min, int, 0444);
MODULE_PARM_DESC(mixer_volume_level_min, "Minimum mixer volume level for dummy driver. Default: -50");
module_param(mixer_volume_level_max, int, 0444);
MODULE_PARM_DESC(mixer_volume_level_max, "Maximum mixer volume level for dummy driver. Default: 100");
module_param(fake_buffer, bool, 0444);
MODULE_PARM_DESC(fake_buffer, "Fake buffer allocations.");


/*
 * mixer interface
 */


#if defined(CONFIG_SND_DEBUG) && defined(CONFIG_SND_PROC_FS)
/*
 * proc interface
 */
static void print_formats(struct snd_dummy *dummy,
              struct snd_info_buffer *buffer)
{
    snd_pcm_format_t i;

    pcm_for_each_format(i) {
        if (dummy->pcm_hw.formats & pcm_format_to_bits(i))
            snd_iprintf(buffer, " %s", snd_pcm_format_name(i));
    }
}

static void print_rates(struct snd_dummy *dummy,
            struct snd_info_buffer *buffer)
{
    static const int rates[] = {
        5512, 8000, 11025, 16000, 22050, 32000, 44100, 48000,
        64000, 88200, 96000, 176400, 192000,
    };
    int i;

    if (dummy->pcm_hw.rates & SNDRV_PCM_RATE_CONTINUOUS)
        snd_iprintf(buffer, " continuous");
    if (dummy->pcm_hw.rates & SNDRV_PCM_RATE_KNOT)
        snd_iprintf(buffer, " knot");
    for (i = 0; i < ARRAY_SIZE(rates); i++)
        if (dummy->pcm_hw.rates & (1 << i))
            snd_iprintf(buffer, " %d", rates[i]);
}

#define get_dummy_int_ptr(dummy, ofs) \
    (unsigned int *)((char *)&((dummy)->pcm_hw) + (ofs))
#define get_dummy_ll_ptr(dummy, ofs) \
    (unsigned long long *)((char *)&((dummy)->pcm_hw) + (ofs))

struct dummy_hw_field {
    const char *name;
    const char *format;
    unsigned int offset;
    unsigned int size;
};
#define FIELD_ENTRY(item, fmt)                         \
{                                                      \
    .name   = #item,                                   \
    .format = fmt,                                     \
    .offset = offsetof(struct snd_pcm_hardware, item), \
    .size   = sizeof(dummy_pcm_hardware.item)          \
}

static const struct dummy_hw_field fields[] = {
    FIELD_ENTRY(formats, "%#llx"),
    FIELD_ENTRY(rates, "%#x"),
    FIELD_ENTRY(rate_min, "%d"),
    FIELD_ENTRY(rate_max, "%d"),
    FIELD_ENTRY(channels_min, "%d"),
    FIELD_ENTRY(channels_max, "%d"),
    FIELD_ENTRY(buffer_bytes_max, "%ld"),
    FIELD_ENTRY(period_bytes_min, "%ld"),
    FIELD_ENTRY(period_bytes_max, "%ld"),
    FIELD_ENTRY(periods_min, "%d"),
    FIELD_ENTRY(periods_max, "%d"),
};

static void dummy_proc_read(struct snd_info_entry *entry,
                struct snd_info_buffer *buffer)
{
    struct snd_dummy *dummy = entry->private_data;
    int i;

    for (i = 0; i < ARRAY_SIZE(fields); i++) {
        snd_iprintf(buffer, "%s ", fields[i].name);
        if (fields[i].size == sizeof(int))
            snd_iprintf(buffer, fields[i].format,
                *get_dummy_int_ptr(dummy, fields[i].offset));
        else
            snd_iprintf(buffer, fields[i].format,
                *get_dummy_ll_ptr(dummy, fields[i].offset));
        if (!strcmp(fields[i].name, "formats"))
            print_formats(dummy, buffer);
        else if (!strcmp(fields[i].name, "rates"))
            print_rates(dummy, buffer);
        snd_iprintf(buffer, "\n");
    }
}

static void dummy_proc_write(struct snd_info_entry *entry,
                 struct snd_info_buffer *buffer)
{
    struct snd_dummy *dummy = entry->private_data;
    char line[64];

    while (!snd_info_get_line(buffer, line, sizeof(line))) {
        char item[20];
        const char *ptr;
        unsigned long long val;
        int i;

        ptr = snd_info_get_str(item, line, sizeof(item));
        for (i = 0; i < ARRAY_SIZE(fields); i++) {
            if (!strcmp(item, fields[i].name))
                break;
        }
        if (i >= ARRAY_SIZE(fields))
            continue;
        snd_info_get_str(item, ptr, sizeof(item));
        if (kstrtoull(item, 0, &val))
            continue;
        if (fields[i].size == sizeof(int))
            *get_dummy_int_ptr(dummy, fields[i].offset) = val;
        else
            *get_dummy_ll_ptr(dummy, fields[i].offset) = val;
    }
}

static void dummy_proc_init(struct snd_dummy *chip)
{
    snd_card_rw_proc_new(chip->card, "dummy_pcm", chip,
                 dummy_proc_read, dummy_proc_write);
}
#else
#define dummy_proc_init(x)
#endif /* CONFIG_SND_DEBUG && CONFIG_SND_PROC_FS */

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

    dummy_proc_init(dummy);

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

static void snd_dummy_unregister_all(void)
{
    int i;

    for (i = 0; i < ARRAY_SIZE(devices); ++i)
        platform_device_unregister(devices[i]);
    platform_driver_unregister(&snd_dummy_driver);
    free_fake_buffer();
}

static int __init alsa_card_dummy_init(void)
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

static void __exit alsa_card_dummy_exit(void)
{
    snd_dummy_unregister_all();
}

module_init(alsa_card_dummy_init)
module_exit(alsa_card_dummy_exit)

