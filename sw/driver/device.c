#include "device.h"

#include <sound/initval.h>

#include "pcm.h"

#define CCO_DRIVER    "cco"

/*==============================Driver interface==============================*/
static int cco_probe(struct platform_device *devptr)
{
    struct snd_card *card;
    struct cco_device *cco;
    int i, err;
    int dev = devptr->id;

    err = snd_devm_card_new(
        &devptr->dev,              /* parent device */
        -1,                        /* card index, -1 makes core assign for us */
        NULL,                      /* card name */
        THIS_MODULE,               /* module */
        sizeof(struct cco_device), /* private_data size */
        &card);                    /* snd_card instance */
    if (err < 0)
        return err;
    cco = card->private_data;
    cco->card = card;

    for (i = 0; i < PCM_DEVICES_PER_CARD; i++) {
        err = cco_pcm_init(cco, i, PCM_SUBSTREAMS_PER_DEVICE);
        if (err < 0)
            return err;
    }

    cco->pcm_hw = cco_pcm_hardware;

    err = cco_mixer_init(cco);
    if (err < 0)
        return err;

    strcpy(card->driver, "cco");
    strcpy(card->shortname, "cuoc_cho_am");
    sprintf(card->longname, "cuoc_cho_am %i", dev + 1);

    err = snd_card_register(card);
    if (err < 0)
        return err;

    platform_set_drvdata(devptr, card);

    return 0;
}

static int cco_suspend(struct device *pdev)
{
    struct snd_card *card = dev_get_drvdata(pdev);
    snd_power_change_state(card, SNDRV_CTL_POWER_D3hot);
    return 0;
}

static int cco_resume(struct device *pdev)
{
    struct snd_card *card = dev_get_drvdata(pdev);
    snd_power_change_state(card, SNDRV_CTL_POWER_D0);
    return 0;
}

static DEFINE_SIMPLE_DEV_PM_OPS(cco_pm, cco_suspend, cco_resume);

static struct platform_driver cco_driver = {
    .probe  = cco_probe,
    .driver = {
        .name = CCO_DRIVER,
        .pm   = &cco_pm,
    },
};
/*============================================================================*/


/*==============================Device management=============================*/
int cco_register_driver(void)
{
    int err;

    err = alloc_fake_buffer();
    if (err < 0)
        return err;

    err = platform_driver_register(&cco_driver);
    if (err < 0)
        return err;

    return 0;
}

void cco_unregister_driver(void)
{
    platform_driver_unregister(&cco_driver);

    free_fake_buffer();
}

static struct platform_device *platform_devices[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = NULL};

int cco_register_device(void)
{

    // Identify id to be used for platform device allocation
    int id = -1;
    for (id = 0; id < SNDRV_CARDS; ++id) {
        if (!platform_devices[id])
            break;
    }
    if (id == SNDRV_CARDS) {
        printk(KERN_ERR "cco: cco_register_device() failed to assign id");
        return -ENODEV;
    }

    // Register platform device, which will cause probe()
    // method to be called if name supplied matches that of
    // driver that was previously registered
    struct platform_device *device = platform_device_register_simple(
        CCO_DRIVER, /* driver name */
        id,         /* id */
        NULL,       /* resources */
        0);         /* num resources */
    if (IS_ERR(device))
        return -ENODEV;

    if (!platform_get_drvdata(device)) {
        printk(KERN_ERR "cco: platform_get_drvdata() failed, check probe()");
        platform_device_unregister(device);
        return -ENODEV;
    }

    platform_devices[id] = device;

    return 0;
}

void cco_unregister_devices(void)
{
    int id;
    for (id = 0; id < SNDRV_CARDS; ++id) {
        struct platform_device *device = platform_devices[id];
        if (device)
            platform_device_unregister(device);
    }
}
/*============================================================================*/
