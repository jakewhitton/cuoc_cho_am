#ifndef CCO_PROTOCOL_H
#define CCO_PROTOCOL_H

#include <linux/if_ether.h>
#include <linux/skbuff.h>

#define NS_PER_SEC             ((ktime_t)1000000000)
#define CCO_HEARTBEAT_INTERVAL ((ktime_t)1 * NS_PER_SEC)
#define CCO_TIMEOUT_INTERVAL   ((ktime_t)3 * CCO_HEARTBEAT_INTERVAL)

/*===================================Header===================================*/
// First 32 bits of the MD5 hash of the string "cuoc cho am"
#define CCO_MAGIC 0x83f8ddef

enum MsgType_t
{
    SESSION_CTL = 0,
    PCM_CTL     = 1,
    PCM_DATA    = 2
};

typedef struct
{
    uint32_t magic; // Should always be set to CCO_MAGIC
    uint8_t generation_id;
    uint8_t msg_type;
    char payload[];
} __attribute__((packed)) Msg_t;

/*============================================================================*/


/*===============================Session control==============================*/
enum SessionCtlMsgType_t
{
    SESSION_CTL_ANNOUNCE           = 0,
    SESSION_CTL_HANDSHAKE_REQUEST  = 1,
    SESSION_CTL_HANDSHAKE_RESPONSE = 2,
    SESSION_CTL_HEARTBEAT          = 3,
    SESSION_CTL_CLOSE              = 4
};

typedef struct
{
    uint8_t msg_type;
} __attribute__((packed)) SessionCtlMsg_t;

/*============================================================================*/


/*=================================PCM control================================*/
enum PcmCtlMsgType_t
{
    PCM_CTL_START = 0,
    PCM_CTL_STOP  = 1
};

typedef struct
{
    uint8_t msg_type;
} __attribute__((packed)) PcmCtlMsg_t;
/*============================================================================*/


/*==================================PCM data==================================*/
#define CHANNELS_PER_PACKET 2
#define SAMPLES_PER_CHANNEL 192
#define SAMPLE_SIZE 3

typedef struct
{
    char data[SAMPLES_PER_CHANNEL * SAMPLE_SIZE];
} __attribute__((packed)) ChannelPcmData_t;

typedef struct
{
    uint32_t seqnum;
    ChannelPcmData_t channels[CHANNELS_PER_PACKET];
} __attribute__((packed)) PcmDataMsg_t;
/*============================================================================*/


/*===================================Helpers==================================*/
static inline int is_valid_cco_packet(struct sk_buff *skb)
{
    struct ethhdr *hdr = eth_hdr(skb);
    uint16_t len = ntohs(hdr->h_proto);
    if (skb_headlen(skb) < len) {
        printk(KERN_DEBUG "cco: rejecting packet due to paged data\n");
        return false;
    }

    if (len < sizeof(Msg_t)) {
        printk(KERN_DEBUG "cco: rejecting packet due to header size\n");
        return false;
    }
    Msg_t *msg = (Msg_t *)skb->data;
    len -= sizeof(Msg_t);

    if (ntohl(msg->magic) != CCO_MAGIC) {
        printk(KERN_DEBUG "cco: rejecting packet due to incorrect magic\n");
        return false;
    }

    switch (msg->msg_type) {
    case SESSION_CTL:
        // Validate session ctl msg length
        if (len != sizeof(SessionCtlMsg_t)) {
            printk(KERN_ERR "cco: session ctl msg has incorrect size %d\n", len);
            return false;
        }

        // Validate session ctl msg_type
        SessionCtlMsg_t *session_msg = (SessionCtlMsg_t *)msg->payload;
        if (session_msg->msg_type < SESSION_CTL_ANNOUNCE ||
            session_msg->msg_type > SESSION_CTL_CLOSE)
        {
            printk(KERN_ERR "cco: invalid session ctl msg_type \"%d\"\n",
                   session_msg->msg_type);
            return false;
        }
        break;

    case PCM_DATA:
        // Validate session ctl msg length
        if (len != sizeof(PcmDataMsg_t)) {
            printk(KERN_ERR "cco: PCM data msg has incorrect size %d\n", len);
            return false;
        }
        break;

    default:
        printk(KERN_ERR "cco: invalid base msg_type \"%d\"\n", msg->msg_type);
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

#endif
