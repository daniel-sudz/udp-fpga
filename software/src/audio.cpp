#include "AudioFile.h"
#include <filesystem>
#include <string>
#include <chrono>


#include "ether.cpp"

int main (int argc, char * argv[]) {
    std::cout<<"[INFO]: running UDP watch"<<std::endl;

    EtherParams params;
    strcpy(params.DEFAULT_IF, argv[2]);
    
    EtherPacketWatchIPV4UDP packet_watch(params);
    if(packet_watch.bind() == -1) {
        perror("[ERROR]: packet watch failed to bind");
        exit(1);
    }
    std::cout<<"[INFO]: packet watch binded successfully!"<<std::endl;


    std::string wave_file = argv[1];
    
    AudioFile<int16_t> audio_file;
    audio_file.load(wave_file);
    audio_file.printSummary();

    int num_samples = audio_file.getNumSamplesPerChannel();
    int samples_per_packet = 300;
    int packet_alias = 2;

    int sample = 0;
    auto start = std::chrono::system_clock::now();

    while(sample < num_samples) {
        auto end = std::chrono::system_clock::now();
        auto elapsed_time = std::chrono::duration<double>(end-start);
        auto elapsed_seconds = elapsed_time.count();


        double time_in_sample = ((double)sample / (double)num_samples) * audio_file.getLengthInSeconds();

        // FPGA does not have a lot of ram so we need to rate limit our send
        if(elapsed_seconds > time_in_sample) {
            uint8_t buffer_aliased[packet_alias + samples_per_packet*4] = {};
            uint32_t* buffer = (uint32_t*)(buffer_aliased+2);

            for(int i=0;i<samples_per_packet;i++) {
                if(i+sample == num_samples) {
                    buffer[i] = 0;
                }
                else {
                    int16_t left_sample = audio_file.samples[0][sample];
                    int16_t right_sample = audio_file.samples[1][sample];

                    buffer[i] = (left_sample << 16) + right_sample;
                    sample++;
                }
            }

            // send audio over UDP!
            packet_watch.send_udp((uint8_t*)buffer_aliased, sizeof(buffer_aliased), 0, {});
            std::cout<<"[INFO]: send UDP packet with sample starting at "<<sample<<"!"<<std::endl;

        }


    }

}