// ----- networking includes ----- //
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>
#include <net/if.h>
#include <netinet/ether.h>

// ----- cpp include ----- //
#include <iostream>




struct EtherParams {
    char DEFAULT_IF[IFNAMSIZ-1] = "enp0s31f6";
    uint16_t ETHER_TYPE_IPV4 = 0x0800;
};

struct EtherPacket {

    struct ether_header ether_header_d;
    struct iphdr ip_header_d; 
    struct udphdr udp_header_d;

    struct ifreq if_ip = {};
    struct sockaddr_storage their_addr;

    EtherPacket(size_t packet_size) {
     //   ether_header_d = (ether_header*) malloc(packet_size);
     //   ip_header_d = (iphdr*) malloc(packet_size + sizeof(ether_header));
     //   udp_header_d = (udphdr*) malloc(packet_size )

    }

    ~EtherPacket () {
    }
};

struct EtherPacketWatch {
    EtherParams params;

    struct ifreq ifopts;	
	struct ifreq if_ip;	
	struct sockaddr_storage their_addr;

    int sock_fd = -1;
    int sock_opt = 1;

    EtherPacketWatch(EtherParams _params = EtherParams()) {
        params = _params;
    }
    
    // open the socket for ethernet
    int bind() {
        // bind the the system etehrnet socket
        if ((sock_fd = socket(PF_PACKET, SOCK_RAW, htons(params.ETHER_TYPE_IPV4))) == -1) {
            perror("[ERROR] ethernet listener socket");	
            return -1;
        }

        // promiscuous mode tells the os to forward all packets from the interface to socket, even those with non-matching MAC addresses 
        // https://serverfault.com/questions/106647/what-does-ifconfig-promisc-mode-do-or-promiscuous-mode-in-general
        strncpy(ifopts.ifr_name, params.DEFAULT_IF, IFNAMSIZ-1);
        ifopts.ifr_flags |= IFF_PROMISC;

        ioctl(sock_fd, SIOCGIFFLAGS, &ifopts);


        // allow re-use of port on program restart 
        // https://stackoverflow.com/a/3233022
        if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &sock_opt, sizeof sock_opt) == -1) {
            perror("[ERROR]: setsockopt");
            close(sock_fd);
            return -1;
        }

        // bind 
        if (setsockopt(sock_fd, SOL_SOCKET, SO_BINDTODEVICE, params.DEFAULT_IF, IFNAMSIZ-1) == -1)	{
            perror("[ERROR]: SO_BINDTODEVICE");
            close(sock_fd);
            return -1;
        }

        // great success 
        return 0;
    }

};


int main() {
    std::cout<<"[INFO]: running UDP watch"<<std::endl;


    EtherPacketWatch packet_watch;
    if(packet_watch.bind() == -1) {
        perror("[ERROR]: packet watch failed to bind");
        exit(1);
    }
    std::cout<<"[INFO]: packet watch binded successfully!"<<std::endl;
}