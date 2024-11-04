#include <linux/delay.h> 
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/ip.h> 
#include <linux/kernel.h>
#include <linux/kfifo.h>
#include <linux/kthread.h>
#include <linux/netdevice.h>
#include <linux/sched.h>
#include <linux/skbuff.h>
#include <linux/slab.h>

#include "ethernet.h"

#include "device.h"
#include "log.h"
#include "protocol.h"

/*===============================Initialization===============================*/
// Defined in "Device discovery" section
static int  device_discovery_init(void);
static void device_discovery_exit(void);

// Defined in "Packet handling" section
static int  packet_init(void);
static void packet_exit(void);

int cco_ethernet_init(void)
{
    int err;

    // Initialize packet send/recv infrastructure
    err = packet_init();
    if (err < 0)
        goto exit_error;

    // Start device discovery service
    err = device_discovery_init();
    if (err < 0)
        goto undo_packet_init;

    return 0;

undo_packet_init:
    packet_exit();
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

void cco_ethernet_exit(void)
{
    packet_exit();
    device_discovery_exit();
}
/*============================================================================*/


/*==============================Device discovery==============================*/
#define DD_KFIFO_SIZE 8
DEFINE_KFIFO(dd_fifo, struct sk_buff *, DD_KFIFO_SIZE);
static struct task_struct *dd_task;

static int dd_impl(void * data);

// Defined in "Packet handling" section
static int send_handshake_request(unsigned char *dest_mac, uint8_t session_id);

static int device_discovery_init(void)
{
    int err;

    // Set up device discovery kthread
    struct task_struct *task = kthread_run(dd_impl, NULL, "cco_discover");
    if (IS_ERR(task)) {
        printk(KERN_ERR "cco: device discovery kthread could not be created\n");
        err = -EAGAIN;
        goto exit_error;
    }
    dd_task = task;
    
    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int dd_impl(void * data)
{
    struct sk_buff *skb;
    while (!kthread_should_stop()) {
        if (kfifo_get(&dd_fifo, &skb)) {
            struct ethhdr *hdr = eth_hdr(skb);
            Msg_t *msg = get_cco_msg(skb);
            switch (msg->msg_type) {
            case ANNOUNCE:
                send_handshake_request(hdr->h_source, 0);
                break;
            case HANDSHAKE_RESPONSE:
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

static void device_discovery_exit(void)
{
    if (dd_task) {
        if (kthread_stop(dd_task) < 0)
            printk(KERN_ERR "cco: could not stop device discovery kthread\n");
        dd_task = NULL;
    }
}
/*============================================================================*/


/*==============================Packet handling===============================*/
const char *intf_name = "eth0";
struct net_device *netdev = NULL;

static struct packet_type *proto;

static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev);

static int packet_init(void)
{
    int err;

    // Search for the interface we plan to use for communication with the FPGA
    netdev = dev_get_by_name(&init_net, intf_name);
    if (!netdev) {
        printk(KERN_ERR "cco: unable to find intf \"%s\"\n", intf_name);
        err = -ENODEV;
        goto exit_error;
    }

    proto = kzalloc(sizeof(*proto), GFP_KERNEL);
    if (!proto) {
        err = -ENOMEM;
        goto undo_select_net_dev;
    }

    proto->type = htons(ETH_P_802_2);
    proto->dev = netdev;
    proto->func = packet_recv;
    dev_add_pack(proto);

    return 0;

undo_select_net_dev:
    netdev = NULL;
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev)
{
    if (!is_valid_cco_packet(skb)) {
        kfree_skb(skb);
        return 0;
    }

    Msg_t *msg = get_cco_msg(skb);
    switch (msg->msg_type) {
    case ANNOUNCE:
    case HANDSHAKE_RESPONSE:
        if (!kfifo_put(&dd_fifo, skb))
            kfree_skb(skb);
        break;

    default:
        printk(KERN_ERR "cco: recv'd message with unsupported msgtype\n");
        kfree_skb(skb);
    }
        
    return 0;
}

static int create_cco_packet(const char * dest_mac, uint8_t msg_type,
                             struct sk_buff **skb_out)
{
    int err;

    // Calculate payload size based on msg_type
    unsigned len = sizeof(Msg_t);
    switch (msg_type) {
    case ANNOUNCE:
        len += sizeof(AnnounceMsg_t);
        break;
    case HANDSHAKE_REQUEST:
        len += sizeof(HandshakeRequestMsg_t);
        break;
    case HANDSHAKE_RESPONSE:
        len += sizeof(HandshakeResponseMsg_t);
        break;
    default:
        printk(KERN_ERR "cco: \"%d\" is not a valid msgtype\n", msg_type);
        err = -EINVAL;
        goto exit_error;
    }

    // Allocate sk_buff
    struct sk_buff *skb = alloc_skb(ETH_HLEN + len, GFP_KERNEL);
    if (IS_ERR(skb)) {
        printk(KERN_ERR "cco: failed to allocate sk_buff\n");
        err = -ENOMEM;
        goto exit_error;
    }
    skb->dev = netdev;

    // Create 802.3 ethernet header
    skb_reserve(skb, ETH_HLEN);
    dev_hard_header(skb, netdev, ETH_P_802_3, dest_mac, netdev->dev_addr, len);

    // Create cco header
    Msg_t *msg = (Msg_t *)skb_put(skb, len);
    msg->magic = htonl(CCO_MAGIC);
    msg->msg_type = msg_type;

    *skb_out = skb;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int send_handshake_request(unsigned char *dest_mac, uint8_t session_id)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(dest_mac, HANDSHAKE_REQUEST, &skb);
    if (err < 0)
        goto exit_error;

    // Ethernet payload
    HandshakeRequestMsg_t *msg;
    msg = (HandshakeRequestMsg_t *)(skb->data + sizeof(Msg_t));
    msg->session_id = session_id;

    if (dev_queue_xmit(skb) != NET_XMIT_SUCCESS) {
        printk(KERN_ERR "cco: failed to enqueue packet\n");
        err = -EAGAIN;
        goto undo_create_packet;
    }

    return 0;

undo_create_packet:
    kfree_skb(skb);
exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static void packet_exit(void)
{
    if (proto) {
        dev_remove_pack(proto);
        proto = NULL;
    }
}
/*============================================================================*/
