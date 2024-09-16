#include "device.h"

#include "log.h"
#include "pcm.h"

#define CCO_DRIVER    "cco"

/*==============================Driver management=============================*/
static int cco_probe(struct platform_device *pdev);
static int cco_suspend(struct device *dev);
static int cco_resume(struct device *dev);

static DEFINE_SIMPLE_DEV_PM_OPS(cco_pm, cco_suspend, cco_resume);

static struct platform_driver cco_driver = {
    .probe  = cco_probe,
    .driver = {
        .name = CCO_DRIVER,
        .pm   = &cco_pm,
    },
};

int cco_register_driver(void)
{
    int err;

    err = alloc_fake_buffer();
    if (err < 0)
        goto exit_error;

    err = platform_driver_register(&cco_driver);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_driver_register() failed\n");
        goto undo_alloc;
    }

    return 0;

undo_alloc:
    free_fake_buffer();
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_unregister_driver(void)
{
    if (driver_find(cco_driver.driver.name, &platform_bus_type))
        platform_driver_unregister(&cco_driver);

    free_fake_buffer();
}

static int cco_probe(struct platform_device *pdev)
{
    int err;

    struct snd_card *card;
    err = snd_card_new(
        &pdev->dev,                  /* parent device */
        -1,                          /* card index, -1 means "assign for us" */
        NULL,                        /* card name */
        THIS_MODULE,                 /* module */
        sizeof(struct cco_device *), /* private_data size */
        &card);                      /* snd_card instance */
    if (err < 0) {
        printk(KERN_ERR "cco: snd_card_new() failed\n");
        goto exit_error;
    }
    strcpy(card->driver, "cco");
    strcpy(card->shortname, "cuoc_cho_am");
    sprintf(card->longname, "cuoc_cho_am %i", pdev->id + 1);

    struct cco_device *cco = pdev_to_cco(pdev);
    card->private_data = (void *)cco;
    cco->card = card;

    for (int i = 0; i < PCM_DEVICES_PER_CARD; i++) {
        err = cco_pcm_init(cco, i, PCM_SUBSTREAMS_PER_DEVICE);
        if (err < 0)
            goto undo_create_card;
    }

    err = cco_mixer_init(cco);
    if (err < 0)
        goto undo_create_card;

    err = snd_card_register(card);
    if (err < 0) {
        printk(KERN_ERR "cco: snd_card_register() failed\n");
        goto undo_create_card;
    }

    return 0;

undo_create_card:
    // Should also free pcm & mixer if they've been created
    snd_card_free(card);
    cco->card = NULL;
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int cco_suspend(struct device *dev)
{
    struct cco_device *cco = dev_to_cco(dev);
    snd_power_change_state(cco->card, SNDRV_CTL_POWER_D3hot);
    return 0;
}

static int cco_resume(struct device *dev)
{
    struct cco_device *cco = dev_to_cco(dev);
    snd_power_change_state(cco->card, SNDRV_CTL_POWER_D0);
    return 0;
}
/*============================================================================*/


/*==============================Device management=============================*/
static struct cco_device *devices[SNDRV_CARDS];

static void cco_release_device(struct device *dev)
{
    struct cco_device *cco = dev_to_cco(dev);
    if (cco->card)
        snd_card_free(cco->card);
    kfree(cco);
}

int cco_register_device(void)
{
    int err;

    // Identify id to be used for platform device allocation
    int id;
    for (id = 0; id <= SNDRV_CARDS; ++id) {
        if (!devices[id])
            break;
    }
    if (id == SNDRV_CARDS) {
        printk(KERN_ERR "cco: cco_register_device() failed to assign id\n");
        err = -ENODEV;
        goto exit_error;
    }

    // Allocate space for cco_device structure
    struct cco_device *cco;
    cco = kzalloc(sizeof(*cco), GFP_KERNEL);
    if (!cco) {
        err = -ENOMEM;
        goto exit_error;
    }

    // Set up platform device to be registered
    cco->pdev.name = CCO_DRIVER;
    cco->pdev.id = id;
    cco->pdev.dev.release = cco_release_device;

    // Register platform device, which will cause probe() method to be called if
    // name supplied matches that of driver that was previously registered
    err = platform_device_register(&cco->pdev);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_device_register() failed\n");
        goto undo_alloc;
    }

    devices[id] = cco;

    return 0;

undo_alloc:
    kfree(cco);
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_unregister_device(struct cco_device *cco)
{
    if (cco->card)
        snd_card_disconnect(cco->card);
    platform_device_unregister(&cco->pdev);
}

void cco_unregister_devices(void)
{
    for (int id = 0; id < SNDRV_CARDS; ++id) {
        struct cco_device *cco = devices[id];
        if (cco)
            cco_unregister_device(cco);
    }
}
/*============================================================================*/
