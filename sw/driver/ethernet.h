#ifndef CCO_ETHERNET_H
#define CCO_ETHERNET_H

#include <linux/kfifo.h>
#include <linux/skbuff.h>
#include <linux/types.h>

#include "device.h"

// Initialization
int cco_ethernet_init(void);
void cco_ethernet_exit(void);

// Packet sending
int send_handshake_request(struct cco_session *session);
int send_heartbeat(struct cco_session *session);
int send_close(struct cco_session *session);
int send_pcm_ctl(struct cco_session *session);
int build_pcm_data(struct cco_session *session, uint32_t seqnum,
                   struct sk_buff **result);
int packet_send(struct cco_session *session, struct sk_buff *skb);

#define SESSION_CTL_FIFO_SIZE 8
typedef STRUCT_KFIFO(struct sk_buff *, SESSION_CTL_FIFO_SIZE) SessionCtlFifo_t;
extern SessionCtlFifo_t session_ctl_fifo;

#endif
