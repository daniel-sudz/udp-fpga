    `timescale 1ns/1ps

    module udp_main(main_clk, main_rst, eth_frame, valid_ip,valid_udp,frame_start,udp_payload);

        //PARAMETERS
        parameter FRAME_WIDTH = 12000; // assuming 1500 byte eth frame width

        // INPUTS
        input wire main_clk;
        input wire main_rst;
        input wire [FRAME_WIDTH-1:0] eth_frame;
        input wire frame_start;

        // OUTPUTS
        output reg valid_ip;
        output reg valid_udp;

        // ETHERNET HEADER PARTS
        wire [47:0] eth_mac_dest;
        wire [47:0] eth_mac_src;
        wire [15:0] eth_type;
        wire [31:0] eth_frc;


        // IPV4 HEADER PARTS
        // assigned conditionally after valid_ip check
        reg [3:0] ip_version;
        reg [3:0] ip_ihl;
        reg [5:0] ip_dscp;
        reg [1:0] ip_ecn;
        reg [15:0] ip_length;
        reg [15:0] ip_id;
        reg [1:0] ip_flags;
        reg [13:0] ip_frag_off;
        reg [7:0] ip_ttl;
        reg [7:0] ip_protocol;
        reg [15:0] ip_checksum;
        reg [31:0] ip_src_addr;
        reg [31:0] ip_dest_addr;

        // UDP HEADER PARTS
        // assigned conditionally after valid_udp check
        reg [15:0] udp_src;
        reg [15:0] udp_dest;
        reg [15:0] udp_length;
        reg [15:0] udp_checksum;
        output reg [11294:0] udp_payload;


    // setup state machine for header parsing
        typedef enum {
            IDLE = 0,
            CHECK_IP = 1,
            PARSE_IP = 2,
            CHECK_UDP = 3,
            PARSE_UDP = 4,
            SKIP_FRAME = 5
        } state_t;

        state_t state = IDLE; // start state is idle

        // grab eth headers
        assign eth_mac_dest = eth_frame[47:0];
        assign eth_mac_src = eth_frame[95:48];
        assign eth_type = eth_frame[111:96];
        assign eth_frc = eth_frame[FRAME_WIDTH-1:11630];


        // frame handling state machine
        always_ff @(posedge main_clk) begin
            if (main_rst) begin
                state <= IDLE;  // on reset return to idle
                valid_ip <= 1'b0;
                valid_udp <= 1'b0;
            end else begin

                case (state)
                    IDLE: begin
                        if (frame_start)  // when new frame starts:
                            state <= CHECK_IP;
                    end

                    CHECK_IP: begin
                        // check ethtype for 0x0800
                        if (eth_type == 16'h0800) begin
                            valid_ip <= 1'b1;
                            state <= PARSE_IP;
                        end else begin
                            valid_ip <= 1'b0;
                            state <= SKIP_FRAME;  // skip frame
                        end
                    end

                    PARSE_IP: begin
                        // conditionally assign ip headers
                        ip_version = eth_frame[115:112];
                        ip_ihl = eth_frame[119:116]; // if > 5, options are present (add options parsing)
                        ip_dscp = eth_frame[125:120];
                        ip_ecn = eth_frame[127:126];
                        ip_length = eth_frame[143:128];
                        ip_id = eth_frame[159:144];
                        ip_flags = eth_frame[161:160];
                        ip_frag_off = eth_frame[175:162];
                        ip_ttl = eth_frame[185:176];
                        ip_protocol = eth_frame[191:184];
                        ip_checksum = eth_frame[207:192];
                        ip_src_addr = eth_frame[239:208];
                        ip_dest_addr = eth_frame[271:240];
                        state <= CHECK_UDP;
                    end

                    CHECK_UDP: begin
                        if (ip_protocol == 8'h11) begin // check if ip_protocol is UDP
                            valid_udp <= 1'b1;
                            state <= PARSE_UDP;
                        end else begin
                            valid_udp <= 1'b0;
                            state <= SKIP_FRAME;
                        end
                    end

                    PARSE_UDP: begin
                        udp_src = eth_frame[287:272];
                        udp_dest = eth_frame[303:288];
                        udp_length = eth_frame[319:304];
                        udp_checksum = eth_frame[335:320];
                        udp_payload = eth_frame[11630:336]; // assuming constant udp length
                        state <= IDLE;
                    end

                    SKIP_FRAME: begin
                        // wait until new frame is detected (to implement based on crc)
                        if (frame_start)
                            state <= IDLE;
                    end
                    
                endcase
            end
        end
    endmodule

