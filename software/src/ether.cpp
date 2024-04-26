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
};

/* Ethernet frames are read directly into the buffer field of this struct */ 
struct EtherPacket {
    // ethernet technically supports variable sized frames (jumbo)
    // but their usage is rather rare and we can stick with fixed sized packets
    uint8_t buff[65536] = {};

    struct ether_header* ether_header_d = (ether_header*) buff;                                   // start of packet has ether header start
    struct iphdr* ip_header_d = (iphdr*) (((uint8_t*)ether_header_d) + sizeof(ether_header));     // ip header is inside of ether header
    
    // since ip header can be variable in size, its location is not actually known until ip header is parsed
    struct udphdr* udp_header_d = nullptr;
};

/* Contains some human-readable metadata alongside the raw ethernet frame*/
struct EtherPacketParsed {
    EtherPacket packet_raw;

    size_t udp_payload_size;
    uint8_t* udp_payload;

    struct ifreq if_ip = {};
    struct sockaddr_storage sender_addr;
    char sender_addr_string[INET6_ADDRSTRLEN];
};

struct EtherPacketWatchIPV4UDP {

private:
    EtherParams params;

    struct ifreq ifopts;	

    int sock_fd = -1;
    int sock_opt = 1;

public:

    EtherPacketWatchIPV4UDP(EtherParams _params = EtherParams()) {
        params = _params;
    }
    
    // open the socket for ethernet
    int bind() {
        // bind the the system etehrnet socket
        if ((sock_fd = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_IP))) == -1) {
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
        
        std::cout<<"received packet with ip header size: "<<header_size<<std::endl;

        // payload size is the size of the whole UDP packet minus the header size
        parsed.udp_payload_size = ntohs(parsed.packet_raw.udp_header_d->len) - sizeof(udphdr);

        std::cout<<"received packet with udp payload size: "<<parsed.udp_payload_size<<std::endl;

        /// get source ip
        ((sockaddr_in *)&parsed.sender_addr)->sin_addr.s_addr = parsed.packet_raw.ip_header_d->saddr;
        inet_ntop(AF_INET, &((struct sockaddr_in*)&parsed.sender_addr)->sin_addr, parsed.sender_addr_string, sizeof(parsed.sender_addr_string));

        std::cout<<"received packet with sender ip: "<<parsed.sender_addr_string<<std::endl;


        return parsed;
    }

    int send_udp(uint8_t* udp_payload, size_t udp_payload_size, uint32_t dest_ip = 0, sockaddr dest_mac = {}) {
        // ethernet packet that is crafted
        EtherPacket packet; 

        // mac address and index of interface being sent to
        struct ifreq if_mac = {};
        struct ifreq if_index = {};
        struct sockaddr_ll send_socket_address_link_layer;

        // no ip options being used so ip header is a fixed size
        packet.udp_header_d  = (udphdr*) (((uint8_t*)packet.ip_header_d) + sizeof(iphdr));
        packet.udp_header_d->len = htons(sizeof(udphdr) + udp_payload_size);


        // set some reasonable defaults in the ip header
        packet.ip_header_d->version = 4;                                                            // ipv4
        packet.ip_header_d->ihl = 5;                                                                // no variable options, 20 byte header
        packet.ip_header_d->ttl = 20;                                                               // hops
        packet.ip_header_d->tot_len = htons(sizeof(iphdr) + sizeof(udphdr) + udp_payload_size);     // ip header + ip payload
        packet.ip_header_d->frag_off = htons(0);                                                    // no fragmented packets
        packet.ip_header_d->protocol = IPPROTO_UDP;


        // get mac address of network interface 
        strncpy(if_mac.ifr_name, params.DEFAULT_IF, sizeof(params.DEFAULT_IF));
        if (ioctl(sock_fd, SIOCGIFHWADDR, &if_mac) < 0) {
            perror("[ERROR]: SIOCGIFHWADDR failed to read hardware address");
            close(sock_fd);
            return -1;
        }

        // get index of network interface 
        strncpy(if_index.ifr_name, params.DEFAULT_IF, sizeof(params.DEFAULT_IF));
        if (ioctl(sock_fd, SIOCGIFINDEX, &if_index) < 0) {
            perror("[ERROR]: SIOCGIFINDEX failed to find index of network device");
            close(sock_fd);
            return -1;
        }

        // set sender/reciever mac address 
        memcpy((char*)packet.ether_header_d->ether_shost, (char*)if_mac.ifr_hwaddr.sa_data, 6);
        memcpy((char*)packet.ether_header_d->ether_dhost, (char*)dest_mac.sa_data, 6);

        memset((char*)packet.ether_header_d->ether_shost, 0, 6);
        memset((char*)packet.ether_header_d->ether_dhost, 0, 6);

        // set protocol to ipv4 UDP
        packet.ether_header_d->ether_type = htons(ETH_P_IP);

        // set the ethernet packet payload
        uint8_t* udp_payload_address = ((uint8_t*)packet.udp_header_d) + sizeof(udphdr);
        memcpy(udp_payload_address, udp_payload, udp_payload_size);

        // set checksums 
        add_ipv4_checksum(packet.ip_header_d);
        add_udp_ipv4_checksum(packet.ip_header_d, packet.udp_header_d);

        // package up send metadata for link-layer system call
        send_socket_address_link_layer.sll_ifindex = if_index.ifr_ifindex;
        send_socket_address_link_layer.sll_halen = ETH_ALEN;
        memcpy((char*)send_socket_address_link_layer.sll_addr, (char*)dest_mac.sa_data, 6);

        // send the ethernet packet
        uint32_t ethernet_frame_size = std::max((long long)(udp_payload_size+sizeof(ether_header)+sizeof(iphdr)+sizeof(udphdr)), 64ll);
	    if (sendto(sock_fd, packet.buff, ethernet_frame_size, 0, (struct sockaddr*)&send_socket_address_link_layer, sizeof(struct sockaddr_ll)) < 0) {
            perror("[ERROR]: failed to send ethernet packet");
            close(sock_fd);
            return -1;
        }

        return 0;
    }

private: 


    /* 
        Get ipv4 checksum without mutating header
    */
    uint16_t get_ipv4_checksum(iphdr* ip_header) {
        iphdr no_checksum_field = *ip_header;
        no_checksum_field.check = 0;
        return ipv4_checksum_algo((uint16_t*)&no_checksum_field, no_checksum_field.ihl*4);
    }

    /*
        Writes checksum into ipv4 header
    */
    void add_ipv4_checksum(iphdr* ip_header) {
        ip_header->check = 0;
        ip_header->check = ipv4_checksum_algo((uint16_t*)&ip_header, ip_header->ihl*4);
    }

    /*
        Writes udp ipv4 checksum into udp header
    */
    void add_udp_ipv4_checksum(iphdr* ip_header, udphdr* udp_header) {
        udp_header->check = get_udp_ipv4_checksum(ip_header, udp_header);
    }

    /* 
        Computes the (optional) UDP checksum field when UDP is used over IPV4.

        reference: https://en.wikipedia.org/wiki/User_Datagram_Protocol#IPv4_pseudo_header
        reference: https://gist.github.com/david-hoze/0c7021434796997a4ca42d7731a7073a
    */
    uint16_t get_udp_ipv4_checksum(iphdr* ip_header, udphdr* udp_header) {
        // checksum is computed with the checksum field zeroed out
        udphdr no_checksum_udp_header = *udp_header;
        no_checksum_udp_header.check = 0;

        uint32_t checksum = 0; 
        
        // assemble the pseudo ipv4 header
        checksum += ((ip_header->saddr>>16)&0xFFFF);        // source IPv4 address
        checksum += ((ip_header->saddr)&0xFFFF);            // source IPv4 address

        checksum += ((ip_header->daddr>>16)&0xFFFF);         // destination IPv4 address
        checksum += ((ip_header->daddr)&0xFFFF);             // destination IPv4 address

        checksum += htons(IPPROTO_UDP);                      // protocol = UDP, zeroes padding                  
        checksum += udp_header->len;                         // length of udp packet

        // append the ip payload
        size_t ip_payload_length = ntohs(udp_header->len);
        uint16_t* ip_payload_location = (uint16_t*)(((uint8_t*)ip_header) + sizeof(iphdr));

        while(ip_payload_length > 1) {
            checksum += *(ip_payload_location++);
            ip_payload_length -= 2;
        }
        // add the last byte if needed
        if(ip_payload_length == 1) {
            checksum += ((uint16_t)(*((uint8_t*)ip_payload_location))) << 16;
        }

        // add the overflow bits to the checksum to preserve 16-bit ones compliment modular arithmetic
        while(checksum>>16) {
            checksum = (checksum & 0xffff) + (checksum >> 16);
        }

        return checksum;
    }

    /*
        addr: start of ipv4 header
        length: number of bytes to compute checksum of

        definition (RFC791-5): 
            "The checksum field is the 16 bit one's complement of the one's complement sum of all 16 bit words in the header. 
            For purposes of computing the checksum, the value of the checksum field is zero."
        
        see reference: https://gist.github.com/david-hoze/0c7021434796997a4ca42d7731a7073a
        see reference: https://www.packetmania.net/en/2021/12/26/IPv4-IPv6-checksum
        see reference: https://www.youtube.com/watch?v=JqEvNxAJtDk
    */
    uint16_t ipv4_checksum_algo(uint16_t* check_addr, size_t check_length) {
        uint32_t checksum = 0; 

        // we are computing 16-bit checksum blocks to 2 bytes of the header are processed at a time
        while(check_length > 1) {
            checksum += *(check_addr++);
            check_length -= 2;
        }  

        // if the header is odd byte length, align the last byte to a 16-bit block
        if(check_length == 0) {
            checksum += *(uint8_t*) check_addr;
        } 

        // add the overflow bits to the checksum to preserve 16-bit ones compliment modular arithmetic
        while(checksum>>16) {
            checksum = (checksum & 0xffff) + (checksum >> 16);
        }

        // take one's compliment 
        checksum = ~checksum; 
        return (uint16_t) checksum;
    }

};


/*
int main() {
    std::cout<<"[INFO]: running UDP watch"<<std::endl;


    EtherPacketWatchIPV4UDP packet_watch;
    if(packet_watch.bind() == -1) {
        perror("[ERROR]: packet watch failed to bind");
        exit(1);
    }
    std::cout<<"[INFO]: packet watch binded successfully!"<<std::endl;

    while(true) {
         EtherPacketParsed packet = packet_watch.read_udp();

         // test sending packet
        uint8_t data[4] = {1, 2, 3, 4};
        packet_watch.send_udp(data, sizeof(data), 0, {});
    }
   
}
*/