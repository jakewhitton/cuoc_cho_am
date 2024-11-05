#ifndef CCO_PROTOCOL_H
#define CCO_PROTOCOL_H

#include <linux/if_ether.h>
#include <linux/skbuff.h>

enum MsgType_t
{
    ANNOUNCE           = 0,
    HANDSHAKE_REQUEST  = 1,
    HANDSHAKE_RESPONSE = 2,
    HEARTBEAT          = 3
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

typedef struct
{
    uint8_t session_id;
} __attribute__((packed)) HandshakeResponseMsg_t;

typedef struct
{
} __attribute__((packed)) HeartbeatMsg_t;

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

#endif
