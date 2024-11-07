#include "device.h"

#include <linux/delay.h>
#include <linux/if_ether.h>
#include <linux/kfifo.h>
#include <linux/kthread.h>
#include <linux/slab.h>
#include <sound/pcm.h>

#include "ethernet.h"
#include "log.h"
#include "pcm.h"
#include "protocol.h"

#define CCO_DRIVER    "cco"

/*==============================Driver management=============================*/
// Full definition is at the bottom of "Driver management" section
static struct platform_driver cco_driver;

int cco_register_driver(void)
{
    int err;

    err = platform_driver_register(&cco_driver);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_driver_register() failed\n");
        goto exit_error;
    }

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_unregister_driver(void)
{
    if (driver_find(cco_driver.driver.name, &platform_bus_type))
        platform_driver_unregister(&cco_driver);
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

    err = cco_pcm_init(cco);
    if (err < 0)
        goto undo_create_card;

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

static DEFINE_SIMPLE_DEV_PM_OPS(cco_pm, cco_suspend, cco_resume);

static struct platform_driver cco_driver = {
    .probe  = cco_probe,
    .driver = {
        .name = CCO_DRIVER,
        .pm   = &cco_pm,
    },
};
/*============================================================================*/


/*=============================Session management=============================*/
// Defined in "Device management" section
static int cco_register_device(void);

static struct task_struct *sm_task;

static int session_manager(void * data)
{
    struct sk_buff *skb;
    while (!kthread_should_stop()) {
        if (kfifo_get(&session_ctl_fifo, &skb)) {
            struct ethhdr *hdr = eth_hdr(skb);
            SessionCtlMsg_t *msg = (SessionCtlMsg_t *)get_cco_msg(skb)->payload;
            switch (msg->msg_type) {
            case SESSION_CTL_ANNOUNCE:
                send_handshake_request(hdr->h_source);
                break;
            case SESSION_CTL_HANDSHAKE_RESPONSE:
                int err = cco_register_device();
                if (err < 0) {
                    printk(KERN_INFO "cco: create device failed\n");
                } else {
                    printk(KERN_INFO "cco: create device succeeded!\n");
                }
                break;
            }
            kfree_skb(skb);
        }
        msleep(100);
    }

    return 0;
}

int cco_session_manager_init(void)
{
    int err;

    // Set up session manager kthread
    struct task_struct *task;
    task = kthread_run(session_manager, NULL, "cco_session_manager");
    if (IS_ERR(task)) {
        printk(KERN_ERR "cco: session manager kthread could not be created\n");
        err = -EAGAIN;
        goto exit_error;
    }
    sm_task = task;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_session_manager_exit(void)
{
    if (sm_task) {
        if (kthread_stop(sm_task) < 0)
            printk(KERN_ERR "cco: could not stop session manager kthread\n");
        sm_task = NULL;
    }
}

/*============================================================================*/


/*==============================Device management=============================*/
static struct cco_device *devices[SNDRV_CARDS];

static int alloc_fake_buffer(struct cco_device *cco);
static void free_fake_buffer(struct cco_device *cco);
static void cco_release_device(struct device *dev);

static int cco_register_device(void)
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

    // Allocate pages to be used by PCM implementation
    err = alloc_fake_buffer(cco);
    if (err < 0)
        goto undo_alloc_device;


    // Set up platform device to be registered
    cco->pdev.name = CCO_DRIVER;
    cco->pdev.id = id;
    cco->pdev.dev.release = cco_release_device;

    // Register platform device, which will cause probe() method to be called if
    // name supplied matches that of driver that was previously registered
    err = platform_device_register(&cco->pdev);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_device_register() failed\n");
        goto undo_alloc_fake_buffer;
    }

    devices[id] = cco;

    return 0;

undo_alloc_fake_buffer:
    free_fake_buffer(cco);
undo_alloc_device:
    kfree(cco);
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_unregister_devices(void)
{
    for (int id = 0; id < SNDRV_CARDS; ++id) {
        struct cco_device *cco = devices[id];
        if (!cco)
            continue;

        if (cco->card)
            snd_card_disconnect(cco->card);

        platform_device_unregister(&cco->pdev);

        devices[id] = NULL;
    }
}

static int alloc_fake_buffer(struct cco_device *cco)
{
    int err;

    for (int i = 0; i < ARRAY_SIZE(cco->page); i++) {
        cco->page[i] = (void *)get_zeroed_page(GFP_KERNEL);
        if (!cco->page[i]) {
            err = -ENOMEM;
            goto undo_alloc;
        }
    }

    return 0;

undo_alloc:
    free_fake_buffer(cco);
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static void free_fake_buffer(struct cco_device *cco)
{
    for (int i = 0; i < ARRAY_SIZE(cco->page); i++) {
        if (cco->page[i]) {
            free_page((unsigned long)cco->page[i]);
            cco->page[i] = NULL;
        }
    }
}

static void cco_release_device(struct device *dev)
{
    struct cco_device *cco = dev_to_cco(dev);
    if (cco->card)
        snd_card_free(cco->card);
    free_fake_buffer(cco);
    kfree(cco);
}
/*============================================================================*/
