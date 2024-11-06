#ifndef CCO_ETHERNET_H
#define CCO_ETHERNET_H

#include <linux/types.h>

// Initialization
int cco_ethernet_init(void);
void cco_ethernet_exit(void);

// Packet sending
int send_handshake_request(unsigned char *dest_mac);
int send_heartbeat(unsigned char *dest_mac);

#endif
