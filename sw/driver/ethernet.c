#include "ethernet.h"

#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/ip.h> 
#include <linux/kernel.h>
#include <linux/netdevice.h>
#include <linux/sched.h>
#include <linux/skbuff.h>
#include <linux/slab.h>

#include "device.h"
#include "log.h"
#include "protocol.h"

/*===============================Initialization===============================*/
const char *intf_name = "eth0";
struct net_device *netdev = NULL;

static struct packet_type *proto;

// Defined in "Packet receiving" section
static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev);

int cco_ethernet_init(void)
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

void cco_ethernet_exit(void)
{
    if (proto) {
        dev_remove_pack(proto);
        proto = NULL;
    }
}
/*============================================================================*/


/*===============================Packet sending===============================*/
static int create_cco_packet(const char * dest_mac, uint8_t msg_type,
                             struct sk_buff **skb_out);

int send_handshake_request(unsigned char *dest_mac)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(dest_mac, SESSION_CTL, &skb);
    if (err < 0)
        goto exit_error;

    SessionCtlMsg_t *msg;
    msg = (SessionCtlMsg_t *)(skb->data + sizeof(Msg_t));
    msg->msg_type = SESSION_CTL_HANDSHAKE_REQUEST;

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

int send_heartbeat(unsigned char *dest_mac)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(dest_mac, SESSION_CTL, &skb);
    if (err < 0)
        goto exit_error;

    SessionCtlMsg_t *msg;
    msg = (SessionCtlMsg_t *)(skb->data + sizeof(Msg_t));
    msg->msg_type = SESSION_CTL_HEARTBEAT;

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

static int create_cco_packet(const char * dest_mac, uint8_t msg_type,
                             struct sk_buff **skb_out)
{
    int err;

    // Calculate payload size based on msg_type
    unsigned len = sizeof(Msg_t);
    switch (msg_type) {
    case SESSION_CTL:
        len += sizeof(SessionCtlMsg_t);
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
/*============================================================================*/


/*==============================Packet receiving==============================*/
static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev)
{
    if (!is_valid_cco_packet(skb)) {
        kfree_skb(skb);
        return 0;
    }

    Msg_t *msg = get_cco_msg(skb);
    switch (msg->msg_type) {
    case SESSION_CTL:
        handle_session_ctl_msg(skb);
        break;

    default:
        printk(KERN_ERR "cco: recv'd message with unsupported msgtype\n");
        kfree_skb(skb);
    }

    return 0;
}
/*============================================================================*/
