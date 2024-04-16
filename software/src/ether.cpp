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

/* Ethernet frames are read directly into the buffer field of this struct */ 
struct EtherPacket {
    // ethernet technically supports variable sized frames (jumbo)
    // but their usage is rather rare and we can stick with fixed sized packets
    uint8_t buff[1500];

    struct ether_header* ether_header_d = (ether_header*) buff;                       // start of packet has ether header start
    struct iphdr* ip_header_d = (iphdr*) (ether_header_d + sizeof(ether_header));     // ip header is inside of ether header
    
    // since ip header can be variable in size, its location is not actually known until ip header is parsed
    struct udphdr* udp_header_d = nullptr;

    struct ifreq if_ip = {};
    struct sockaddr_storage their_addr;
};

/* Contains some human-readable metadata alongside the raw ethernet frame*/
struct EtherPacketParsed {
    EtherPacket packet_raw;

    size_t udp_payload_size;
    uint8_t* udp_payload;
};

struct EtherPacketWatch {
    EtherParams params;

    struct ifreq ifopts;	

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

    EtherPacketParsed read_udp() {
        // read a UDP packet
        EtherPacketParsed parsed;
        int bytes_recv = recvfrom(sock_fd, parsed.packet_raw.buff, sizeof(parsed.packet_raw.buff), 0, NULL, NULL);

        std::cout<<"received packet of size: "<<bytes_recv<<std::endl;
        std::cout<<"received packet of type: "<<ntohs(parsed.packet_raw.ether_header_d->ether_type)<<std::endl;

        // the IP header is variable in size and the ihl field carries the number of 32-bit words the header contains
        int header_size = (parsed.packet_raw.ip_header_d->ihl * 4);
        parsed.packet_raw.udp_header_d = (udphdr*) ((uint8_t*)parsed.packet_raw.ip_header_d + header_size);
        parsed.udp_payload = ((uint8_t*) parsed.packet_raw.udp_header_d) + sizeof(udphdr);
        
        // payload size is the size of the whole UDP packet minux the header size
        parsed.udp_payload_size = ntohs(parsed.packet_raw.udp_header_d->len) - sizeof(udphdr);

        std::cout<<"udp payload size: "<<parsed.udp_payload_size<<std::endl;


        std::cout<<"alive"<<std::endl;

        return parsed;
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


    EtherPacketParsed packet = packet_watch.read_udp();
}