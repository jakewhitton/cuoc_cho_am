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


/*=============================Protocol definition============================*/
enum MsgType_t
{
    ANNOUNCE           = 0,
    HANDSHAKE_REQUEST  = 1,
    HANDSHAKE_RESPONSE = 2
};

// First 32 bits of the MD5 hash of the string "cuoc cho am"
#define CCO_MAGIC 0x83f8ddef

typedef struct
{
    uint32_t magic; // Should always be set to CCO_MAGIC
    uint8_t msg_type;
    char payload[];
} __attribute__((packed)) Msg_t;

typedef struct
{
} __attribute__((packed)) AnnounceMsg_t;

typedef struct
{
    uint8_t session_id;
} __attribute__((packed)) HandshakeRequestMsg_t;

struct
{
    uint8_t session_id;
} __attribute__((packed)) HandshakeResponseMsg_t;

static inline int is_valid_cco_packet(struct sk_buff *skb)
{
    struct ethhdr *hdr = eth_hdr(skb);
    uint16_t len = ntohs(hdr->h_proto);
    if (skb_headlen(skb) < len) {
        printk(KERN_INFO "rejecting packet due to paged data\n");
        return false;
    }

    if (len < sizeof(Msg_t)) {
        printk(KERN_INFO "rejecting packet due to header size\n");
        return false;
    }
    Msg_t *msg = (Msg_t *)skb->data;
    len -= sizeof(Msg_t);

    if (ntohl(msg->magic) != CCO_MAGIC) {
        printk(KERN_INFO "rejecting packet due to incorrect magic\n");
        return false;
    }

    switch (msg->msg_type) {
    case ANNOUNCE:
        if (len != sizeof(AnnounceMsg_t)) {
            printk(KERN_ERR "AnnounceMsg_t has incorrect size %d\n", len);
            return false;
        }
        break;
    case HANDSHAKE_REQUEST:
        if (len != sizeof(HandshakeRequestMsg_t)) {
            printk(KERN_ERR "HandshakeRequestMsg_t has incorrect size %d\n", len);
            return false;
        }
        break;
    case HANDSHAKE_RESPONSE:
        if (len != sizeof(HandshakeResponseMsg_t)) {
            printk(KERN_ERR "HandshakeResponseMsg_t has incorrect size %d\n", len);
            return false;
        }
        break;
    default:
        return false;
    }

    return true;
}

// Assumes that is_valid_cco_packet has already been called
static inline Msg_t *get_cco_msg(struct sk_buff *skb)
{
    return (Msg_t *)skb->data;
}
/*============================================================================*/


/*==============================Device discovery==============================*/
#define DD_KFIFO_SIZE 8
DEFINE_KFIFO(dd_fifo, struct sk_buff *, DD_KFIFO_SIZE);
static struct task_struct *dd_task;

static int dd_impl(void * data);

// Defined in "Packet handling" section
static void send_handshake_request(unsigned char *dest_mac, uint8_t session_id);

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
static struct packet_type *proto;

static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev);

static int packet_init(void)
{
    int err;

    proto = kzalloc(sizeof(*proto), GFP_KERNEL);
    if (!proto) {
        err = -ENOMEM;
        goto exit_error;
    }

    proto->type = htons(ETH_P_802_2);
    proto->dev = dev_get_by_name(&init_net, "eth0");
    proto->func = packet_recv;
    dev_add_pack(proto);

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static struct net_device *netdev = NULL;

static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev)
{
    if (!is_valid_cco_packet(skb)) {
        kfree_skb(skb);
        return 0;
    }

    if (!netdev) {
        netdev = dev;
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

static void send_handshake_request(unsigned char *dest_mac, uint8_t session_id)
{
    if (!netdev) {
        printk(KERN_ERR "Do not have net device to use!!\n");
        return;
    }

    struct sk_buff *skb = alloc_skb(ETH_FRAME_LEN, GFP_KERNEL);
    if (IS_ERR(skb)) {
        printk(KERN_ERR "Failed to allocate sk_buff\n");
        return;
    }

    skb_reserve(skb, ETH_HLEN);

    // Ethernet header
    unsigned len = sizeof(Msg_t) + sizeof(HandshakeRequestMsg_t);
    dev_hard_header(skb, netdev, ETH_P_802_3, dest_mac, netdev->dev_addr, len);

    // Ethernet payload
    char *payload = skb_put(skb, len);
    Msg_t *msg = (Msg_t *)payload;
    msg->magic = htonl(CCO_MAGIC);
    msg->msg_type = HANDSHAKE_REQUEST;
    HandshakeRequestMsg_t * hs_req = (HandshakeRequestMsg_t *)msg->payload;
    hs_req->session_id = session_id;

    skb->dev = netdev;

    if (dev_queue_xmit(skb) != NET_XMIT_SUCCESS) {
        printk(KERN_ERR "Failed to enqueue packet\n");
        kfree_skb(skb);
    }
}

static void packet_exit(void)
{
    if (proto) {
        dev_remove_pack(proto);
        proto = NULL;
    }
}
/*============================================================================*/
