#ifndef CCO_ETHERNET_H
#define CCO_ETHERNET_H

#include <linux/kfifo.h>
#include <linux/skbuff.h>
#include <linux/types.h>

// Initialization
int cco_ethernet_init(void);
void cco_ethernet_exit(void);

// Packet sending
int send_handshake_request(unsigned char *dest_mac);
int send_heartbeat(unsigned char *dest_mac);

#define SESSION_CTL_FIFO_SIZE 8
typedef STRUCT_KFIFO(struct sk_buff *, SESSION_CTL_FIFO_SIZE) SessionCtlFifo_t;
extern SessionCtlFifo_t session_ctl_fifo;

#endif
