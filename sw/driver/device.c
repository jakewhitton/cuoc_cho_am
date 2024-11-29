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


/*==============================Device management=============================*/
static int alloc_fake_buffer(struct cco_device *cco);
static void free_fake_buffer(struct cco_device *cco);
static void cco_release_device(struct device *dev);

static struct cco_device *cco_register_device(int id)
{
    int err;

    // Allocate space for cco_device structure
    struct cco_device *dev;
    dev = kzalloc(sizeof(*dev), GFP_KERNEL);
    if (!dev) {
        err = -ENOMEM;
        goto exit_error;
    }

    // Allocate pages to be used by PCM implementation
    err = alloc_fake_buffer(dev);
    if (err < 0)
        goto undo_alloc_device;


    // Set up platform device to be registered
    dev->pdev.name = CCO_DRIVER;
    dev->pdev.id = id;
    dev->pdev.dev.release = cco_release_device;

    // Register platform device, which will cause probe() method to be called if
    // name supplied matches that of driver that was previously registered
    err = platform_device_register(&dev->pdev);
    if (err < 0) {
        printk(KERN_ERR "cco: platform_device_register() failed\n");
        goto undo_alloc_fake_buffer;
    }

    return dev;

undo_alloc_fake_buffer:
    free_fake_buffer(dev);
undo_alloc_device:
    kfree(dev);
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return NULL;
}

void cco_unregister_device(struct cco_device *dev)
{
    if (dev->card)
        snd_card_disconnect(dev->card);

    platform_device_unregister(&dev->pdev);
}

static int alloc_fake_buffer(struct cco_device *dev)
{
    int err;

    for (int i = 0; i < ARRAY_SIZE(dev->page); i++) {
        dev->page[i] = (void *)get_zeroed_page(GFP_KERNEL);
        if (!dev->page[i]) {
            err = -ENOMEM;
            goto undo_alloc;
        }
    }

    return 0;

undo_alloc:
    free_fake_buffer(dev);
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static void free_fake_buffer(struct cco_device *dev)
{
    for (int i = 0; i < ARRAY_SIZE(dev->page); i++) {
        if (dev->page[i]) {
            free_page((unsigned long)dev->page[i]);
            dev->page[i] = NULL;
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


/*=============================Session management=============================*/
static struct cco_session *sessions[SNDRV_CARDS];

static struct task_struct *sm_task;

struct cco_session *cco_get_session(unsigned char *mac, uint8_t generation_id)
{
    for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
        struct cco_session *session = sessions[i];
        if (!session)
            continue;

        if (memcmp(session->mac, mac, ETH_ALEN) == 0 &&
            session->generation_id == generation_id)
            return session;
    }

    return NULL;
}

static struct cco_session *
cco_create_session(unsigned char *mac, uint8_t generation_id)
{
    for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
        struct cco_session *session = sessions[i];
        if (session)
            continue;

        session = kzalloc(sizeof(*session), GFP_KERNEL);
        session->id = i;
        memcpy(session->mac, mac, ETH_ALEN);
        session->generation_id = generation_id;

        ktime_t now = ktime_get();
        session->ts_last_recv = now;
        session->ts_last_send = now;

        printk(KERN_INFO "cco: [%pM, %d]: session opened\n",
               session->mac, session->generation_id);

        sessions[i] = session;
        return session;
    }

    return NULL;
}

static void cco_close_session(struct cco_session *session, const char *reason)
{
    for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
        if (sessions[i] == session)
            sessions[i] = NULL;
    }

    if (session->dev) {
        // Note: kfree of cco_device occurs in cco_release_device()
        cco_unregister_device(session->dev);
    }

    printk(KERN_INFO "cco: [%pM, %d]: session closed",
           session->mac, session->generation_id);
    if (reason) {
        printk(KERN_CONT ", reason=\"%s\"", reason);
    }
    printk(KERN_CONT "\n");

    kfree(session);
}

void cco_close_sessions(void)
{
    for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
        struct cco_session *session = sessions[i];
        if (session) {
            send_close(session);
            cco_close_session(session, NULL);
        }
    }
}

static void handle_session_ctl_msg(struct sk_buff *skb)
{
    // Extract sections of the packet
    struct ethhdr *hdr = eth_hdr(skb);
    Msg_t *msg = get_cco_msg(skb);

    // Locate or create session
    struct cco_session *session;
    session = cco_get_session(hdr->h_source, msg->generation_id);
    if (!session) {
        session = cco_create_session(hdr->h_source, msg->generation_id);
        if (!session) {
            printk(KERN_ERR "cco: failed to open session for mac=%pM, "
                   "gen_id=%d\n", hdr->h_source, msg->generation_id);
            return;
        }
    }

    SessionCtlMsg_t *session_msg = (SessionCtlMsg_t *)msg->payload;
    switch (session_msg->msg_type) {
    case SESSION_CTL_ANNOUNCE:
        send_handshake_request(session);
        break;

    case SESSION_CTL_HANDSHAKE_RESPONSE:
        struct cco_device *dev = cco_register_device(session->id);
        if (!dev) {
            send_close(session);
            cco_close_session(session, "failed to register cco_device");
            return;
        }
        printk(KERN_ERR "cco: [%pM, %d]: device created w/ id=%d\n",
               hdr->h_source, msg->generation_id, session->id);
        session->dev = dev;
        break;

    case SESSION_CTL_CLOSE:
        cco_close_session(session, "FPGA closed session");
        break;
    }
}

static int session_manager(void * data)
{
    struct sk_buff *skb;
    while (!kthread_should_stop()) {

        // Handle any pending session ctl msgs
        while (kfifo_get(&session_ctl_fifo, &skb)) {
            handle_session_ctl_msg(skb);
            kfree_skb(skb);
        }

        // Close any sessions that have exceeded heartbeat timout
        for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
            struct cco_session *session = sessions[i];
            if (!session)
                continue;

            ktime_t now = ktime_get();
            if (now - session->ts_last_recv > CCO_TIMEOUT_INTERVAL)
                cco_close_session(session, "heartbeat timeout");
        }

        // Send heartbeat on any session that needs it
        for (unsigned i = 0; i < ARRAY_SIZE(sessions); ++i) {
            struct cco_session *session = sessions[i];
            if (!session)
                continue;

            ktime_t now = ktime_get();
            if (now - session->ts_last_send > CCO_HEARTBEAT_INTERVAL)
                send_heartbeat(session);
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
