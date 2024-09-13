#include "device.h"

#include <sound/initval.h>

#include "pcm.h"

#define CCO_DRIVER    "cco"

static struct cco_device *devices[SNDRV_CARDS];

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
        goto exit_error;

    err = platform_driver_register(&cco_driver);
    if (err < 0)
        goto undo_alloc;

    return 0;

undo_alloc:
	free_fake_buffer();
exit_error:
	return err;
}

void cco_unregister_driver(void)
{
    platform_driver_unregister(&cco_driver);

    free_fake_buffer();
}

static void cco_release_device(struct device *dev)
{
	struct cco_device *cco = container_of(
		dev, struct cco_device, platform_device.dev);
    kfree(cco);
}

int cco_register_device(void)
{
	int err, id;
	struct cco_device *cco;

    // Identify id to be used for platform device allocation
    for (id = 0; id < SNDRV_CARDS; ++id) {
        if (!devices[id])
            break;
    }
    if (id == SNDRV_CARDS) {
        printk(KERN_ERR "cco: cco_register_device() failed to assign id");
		err = -ENODEV;
		goto exit_error;
    }

	// Set up platform device to be registered
	cco = kzalloc(sizeof(*cco), GFP_KERNEL);
	if (!cco) {
		err = -ENOMEM;
		goto exit_error;

	}
	cco->platform_device.name = CCO_DRIVER;
	cco->platform_device.id = id;
	cco->platform_device.dev.release = cco_release_device;

    // Register platform device, which will cause probe() method to be called if
	// name supplied matches that of driver that was previously registered
    err = platform_device_register(&cco->platform_device);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_device_register() failed");
		goto undo_alloc;
	}

	// Verify that private driver data has been set correctly
    if (!platform_get_drvdata(&cco->platform_device)) {
        printk(KERN_ERR "cco: platform_get_drvdata() failed, check probe()");
		err = -ENODEV;
		goto undo_register;
    }

    devices[id] = cco;

    return 0;

undo_register:
	// Note: platform_device_unregister() will call cco_release_device(), which
	// will free the cco_device structure, so we skip over undo_alloc to avoid
	// double freeing
	platform_device_unregister(&cco->platform_device);
	goto exit_error;
undo_alloc:
	kfree(cco);
exit_error:
	return err;
}

void cco_unregister_device(struct cco_device *cco)
{
	platform_device_unregister(&cco->platform_device);
}

void cco_unregister_devices(void)
{
    int id;
    for (id = 0; id < SNDRV_CARDS; ++id) {
		struct cco_device *cco = devices[id];
        if (cco)
			cco_unregister_device(cco);
    }
}
/*============================================================================*/
