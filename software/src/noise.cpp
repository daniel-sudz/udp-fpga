#include "ether.cpp"


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
