#include "ethernet.h"

#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/ip.h> 
#include <linux/kernel.h>
#include <linux/netdevice.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/timekeeping.h>

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

    INIT_KFIFO(session_ctl_fifo);

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
static int create_cco_packet(struct cco_session *session, uint8_t msg_type,
                             struct sk_buff **skb_out);

int send_handshake_request(struct cco_session *session)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(session, SESSION_CTL, &skb);
    if (err < 0)
        goto exit_error;

    SessionCtlMsg_t *msg;
    msg = (SessionCtlMsg_t *)skb_put(skb, sizeof(SessionCtlMsg_t));
    msg->msg_type = SESSION_CTL_HANDSHAKE_REQUEST;

    err = packet_send(session, skb);
    if (err < 0)
        goto exit_error;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

int send_heartbeat(struct cco_session *session)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(session, SESSION_CTL, &skb);
    if (err < 0)
        goto exit_error;

    SessionCtlMsg_t *msg;
    msg = (SessionCtlMsg_t *)skb_put(skb, sizeof(SessionCtlMsg_t));
    msg->msg_type = SESSION_CTL_HEARTBEAT;

    err = packet_send(session, skb);
    if (err < 0)
        goto exit_error;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

int send_close(struct cco_session *session)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(session, SESSION_CTL, &skb);
    if (err < 0)
        goto exit_error;

    SessionCtlMsg_t *msg;
    msg = (SessionCtlMsg_t *)skb_put(skb, sizeof(SessionCtlMsg_t));
    msg->msg_type = SESSION_CTL_CLOSE;

    err = packet_send(session, skb);
    if (err < 0)
        goto exit_error;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

int send_pcm_ctl(struct cco_session *session, uint8_t msg_type)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(session, PCM_CTL, &skb);
    if (err < 0)
        goto exit_error;

    PcmCtlMsg_t *msg;
    msg = (PcmCtlMsg_t *)skb_put(skb, sizeof(PcmCtlMsg_t));
    msg->msg_type = msg_type;

    err = packet_send(session, skb);
    if (err < 0)
        goto exit_error;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

int build_pcm_data(struct cco_session *session, uint32_t seqnum,
                   struct sk_buff **result)
{
    int err;

    struct sk_buff *skb;
    err = create_cco_packet(session, PCM_DATA, &skb);
    if (err < 0)
        goto exit_error;

    PcmDataMsg_t *msg;
    msg = (PcmDataMsg_t *)skb_put(skb, sizeof(PcmDataMsg_t));
    msg->seqnum = htonl(seqnum);

    *result = skb;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

static int create_cco_packet(struct cco_session *session, uint8_t msg_type,
                             struct sk_buff **skb_out)
{
    int err;

    // Calculate payload size based on msg_type
    unsigned len = sizeof(Msg_t);
    switch (msg_type) {
    case SESSION_CTL:
        len += sizeof(SessionCtlMsg_t);
        break;
    case PCM_CTL:
        len += sizeof(PcmCtlMsg_t);
        break;
    case PCM_DATA:
        len += sizeof(PcmDataMsg_t);
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
    dev_hard_header(skb, netdev, ETH_P_802_3, session->mac, netdev->dev_addr, len);

    // Create cco header
    Msg_t *msg = (Msg_t *)skb_put(skb, sizeof(Msg_t));
    msg->magic = htonl(CCO_MAGIC);
    msg->generation_id = session->generation_id;
    msg->msg_type = msg_type;

    *skb_out = skb;

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}

int packet_send(struct cco_session *session, struct sk_buff *skb)
{
    int err;

    if (dev_queue_xmit(skb) != NET_XMIT_SUCCESS) {
        printk(KERN_ERR "cco: failed to enqueue packet\n");
        err = -EAGAIN;
        kfree_skb(skb);
        goto exit_error;
    }

    session->ts_last_send = ktime_get();

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;

}
/*============================================================================*/


/*==============================Packet receiving==============================*/
SessionCtlFifo_t session_ctl_fifo;

static int packet_recv(struct sk_buff *skb, struct net_device *dev,
                       struct packet_type *pt, struct net_device *orig_dev)
{
    if (!is_valid_cco_packet(skb)) {
        kfree_skb(skb);
        return 0;
    }

    // Update recv timestamp for the session if it exists
    struct ethhdr *hdr = eth_hdr(skb);
    Msg_t *msg = get_cco_msg(skb);
    struct cco_session *session;
    session = cco_get_session(hdr->h_source, msg->generation_id);
    if (session) {
        session->ts_last_recv = ktime_get();
    }

    switch (msg->msg_type) {
    case SESSION_CTL:
        if (!kfifo_put(&session_ctl_fifo, skb))
            kfree_skb(skb);
        break;

    default:
        printk(KERN_ERR "cco: recv'd message with unsupported msgtype\n");
        kfree_skb(skb);
    }

    return 0;
}
/*============================================================================*/
