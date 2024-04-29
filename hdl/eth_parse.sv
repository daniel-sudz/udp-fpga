`timescale 1ns / 1ps

module eth_parse(
    input wire clk,
    input wire rst,
    input wire [31:0] rd_data, // read data from ram
    output reg [8:0] rd_addr, // read address from ram
    output reg [31:0] wr_data, // write data to ram
    output reg [8:0] wr_addr, // write address to ram
    output reg [8:0] last_addr,
    output reg start_read, 
    output reg wr_ena, // write enable ram
    output reg valid_ip,
    output reg valid_udp,
    input wire newpacket
);

    // intermediates
    logic [31:0] eth_packet;
    logic [15:0] length;

    //packet reconstruct
    always_comb begin
    eth_packet[7:0]={rd_data[3:0],rd_data[7:4]};
    eth_packet[15:8]={rd_data[11:8],rd_data[15:12]};
    eth_packet[23:16]={rd_data[19:16],rd_data[23:20]};
    eth_packet[31:24]={rd_data[27:24],rd_data[31:28]};
    end

    // params
    parameter BYTE_WIDTH = 8;
    parameter WORD_BYTES = 4;

    // states
    typedef enum {
        DETECT_PREAMBLE = 0,
        PARSE_ETH = 1,
        DETECT_OPTIONS = 2,
        PARSE_IP = 3,
        SEND_PAYLOAD = 4,
        IDLE = 5,
        PARSE_LENGTH = 6
    } state_t;

    state_t state = IDLE; // set base state

    reg [7:0] header_buffer[20:0]; // store header
    reg [7:0] preamble_buffer[7:0]; // hold 8 bytes
    reg [4:0] byte_count = 0;       // count processed bytes



    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            rd_addr <= 0;
            byte_count <= 0;
            valid_ip <= 0;
            valid_udp <= 0;
            wr_addr <= 0;
            wr_ena <= 0;
            start_read <= 0;
            last_addr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if(newpacket) begin
                        state <= DETECT_PREAMBLE;
                        rd_addr <= 9'd0;
                        wr_addr <= 0;
                        last_addr <= 0;
                    end
                    start_read <= 0;
                end
                DETECT_PREAMBLE: begin
                    // reset start read signal and last address index

                    // update preamble
                    preamble_buffer[7] <= preamble_buffer[3];
                    preamble_buffer[6] <= preamble_buffer[2];
                    preamble_buffer[5] <= preamble_buffer[1];
                    preamble_buffer[4] <= preamble_buffer[0];
                    preamble_buffer[3] <= eth_packet[7:0];
                    preamble_buffer[2] <= eth_packet[15:8];
                    preamble_buffer[1] <= eth_packet[23:16];
                    preamble_buffer[0] <= eth_packet[31:24];  // load in data

                    // check for preamble
                    if (preamble_buffer[7] == 8'h55 && preamble_buffer[6] == 8'h55 &&
                        preamble_buffer[5] == 8'h55 && preamble_buffer[4] == 8'h55 &&
                        preamble_buffer[3] == 8'h55 && preamble_buffer[2] == 8'h55 &&
                        preamble_buffer[1] == 8'h55 && preamble_buffer[0] == 8'hD5) begin
                        state <= PARSE_ETH; // check for preamble
                        byte_count <= 0;
                        end else begin
                            rd_addr <= rd_addr + 1; // Increment read address only in this state
                        end
                    
                end
                PARSE_ETH: begin
                    // shift in data to header buffer
                    if (byte_count < 14) begin
                        header_buffer[byte_count] <= eth_packet[7:0];
                        header_buffer[byte_count + 1] <= eth_packet[15:8];
                        header_buffer[byte_count + 2] <= eth_packet[23:16];
                        header_buffer[byte_count + 3] <= eth_packet[31:24];
                        byte_count <= byte_count + 4; // increment byte count
                    end

                    // check if eth type should have been loaded in or not
                    if (byte_count >= 14) begin
                        // check eth type
                        if (header_buffer[12] == 8'h08 & header_buffer[13] == 8'h00) begin
                            valid_ip <= 1;
                            state <= DETECT_OPTIONS; // next state
                            byte_count <= 0; // reset counter so i can reuse the header
                            rd_addr <= rd_addr - 1;
                        end else begin
                            state <= IDLE; // go back and look for new frame
                        end
                    end else begin
                        rd_addr <= rd_addr + 1; // read next word from ram
                    end
                end

                DETECT_OPTIONS: begin
                    // Process four bytes from the word read from RAM
                    if (byte_count < 15) begin
                        header_buffer[byte_count] <= eth_packet[7:0];
                        header_buffer[byte_count + 1] <= eth_packet[15:8];
                        header_buffer[byte_count + 2] <= eth_packet[23:16];
                        header_buffer[byte_count + 3] <= eth_packet[31:24];
                        byte_count <= byte_count + 4; // Increment byte_count by 4
                    end

                    // Check if we've processed the IHL from the first byte
                    if (byte_count >= 1) begin
                        // Check IHL (first 4 bits of the first byte)
                        if ((header_buffer[2] & 8'h0F) > 5) begin
                            state <= IDLE; // IP header has options, skip packet
                        end else begin
                            state <= PARSE_IP; // Move to IP parsing
                            byte_count <= 0; // reset counter so i can reuse the header
                        end
                    end else begin
                        rd_addr <= rd_addr + 1; // Prepare to read the next word from RAM
                    end
                end
                PARSE_IP: begin
                    if (byte_count < 8) begin
                        header_buffer[byte_count] <= eth_packet[7:0];
                        header_buffer[byte_count + 1] <= eth_packet[15:8];
                        header_buffer[byte_count + 2] <= eth_packet[23:16];
                        header_buffer[byte_count + 3] <= eth_packet[31:24];
                        byte_count <= byte_count + 4; // continue reading data
                    end

                    if (byte_count >= 8) begin
                        if (header_buffer[7] == 8'h11) begin // check for udp
                            valid_udp <= 1;
                            byte_count <= 0; // reset counter so i can reuse the header
                            state <= PARSE_LENGTH; // begin sending payload
                        end else begin
                            state <= IDLE; // Not UDP, detect new preamble
                        end
                    end else begin
                        rd_addr <= rd_addr + 1; // read next word from ram
                    end
                end

                PARSE_LENGTH: begin
                    if (byte_count < 19) begin
                        header_buffer[byte_count] <= eth_packet[7:0];
                        header_buffer[byte_count + 1] <= eth_packet[15:8];
                        header_buffer[byte_count + 2] <= eth_packet[23:16];
                        header_buffer[byte_count + 3] <= eth_packet[31:24];
                        byte_count <= byte_count + 4; // continue reading data
                    end

                    if (byte_count >= 19) begin
                        byte_count <= 0; // reset counter so i can reuse the header
                        length={header_buffer[18],header_buffer[19]};
                        // state <= SEND_PAYLOAD; // begin sending payload
                        // //SKIP
                        // valid_udp <= 1;
                        // rd_addr <= 9'd13;
                        wr_ena <= 1;
                        state <= SEND_PAYLOAD;
                        rd_addr <= rd_addr + 1; // read next word from ram
                    end
                    rd_addr <= rd_addr + 1; // read next word from ram
                end

                SEND_PAYLOAD: begin
                    // start streaming output
                    // wr_ena <= 1;
                    wr_data <= rd_data; // write to ram
                    wr_addr <= wr_addr + 1;

                    // shift data through

                    //if (wr_addr>=9'd299) begin
                    if (wr_addr>=(length[8:0]-9'd9)) begin
                        state <= IDLE; // jump back to start
                        wr_ena <= 0; // stop writing to ram
                        last_addr <= wr_addr;
                        start_read <= 1;
                    end
                    rd_addr <= rd_addr + 1; 
                end

                default: begin
                    state <= IDLE; // handle random weirdness
                end
            endcase
        end
    end
endmodule
