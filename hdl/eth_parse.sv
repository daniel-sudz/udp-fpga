`timescale 1ns / 1ps

module udp_main(
    input wire clk,
    input wire rst,
    input wire [31:0] rd_data, // read data from ram
    output reg [9:0] rd_addr, // read address from ram
    output reg [31:0] wr_data, // write data to ram
    output reg [9:0] wr_addr, // write address to ram
    output reg wr_ena, // write enable ram
    output reg valid_ip,
    output reg valid_udp
);

    // params
    parameter BYTE_WIDTH = 8;
    parameter WORD_BYTES = 4;

    // states
    typedef enum {
        DETECT_PREAMBLE = 0,
        PARSE_ETH = 1,
        DETECT_OPTIONS = 2,
        PARSE_IP = 3,
        SEND_PAYLOAD = 4
    } state_t;

    state_t state = DETECT_PREAMBLE; // set base state

    reg [7:0] header_buffer[13:0]; // store header
    reg [7:0] preamble_buffer[7:0]; // hold 8 bytes
    reg [3:0] byte_count = 0;       // count processed bytes

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= DETECT_PREAMBLE;
            rd_addr <= 0;
            byte_count <= 0;
            valid_ip <= 0;
            valid_udp <= 0;
            wr_addr <= 0;
            wr_ena <= 0;
        end else begin
            case (state)
                DETECT_PREAMBLE: begin
                    // update preamble
                    preamble_buffer[7] <= preamble_buffer[6];
                    preamble_buffer[6] <= preamble_buffer[5];
                    preamble_buffer[5] <= preamble_buffer[4];
                    preamble_buffer[4] <= preamble_buffer[3];
                    preamble_buffer[3] <= preamble_buffer[2];
                    preamble_buffer[2] <= preamble_buffer[1];
                    preamble_buffer[1] <= preamble_buffer[0];
                    preamble_buffer[0] <= rd_data[7:0];  // load in data

                    // check for preamble
                    if (preamble_buffer[7] == 8'h55 && preamble_buffer[6] == 8'h55 &&
                        preamble_buffer[5] == 8'h55 && preamble_buffer[4] == 8'h55 &&
                        preamble_buffer[3] == 8'h55 && preamble_buffer[2] == 8'h55 &&
                        preamble_buffer[1] == 8'h55 && preamble_buffer[0] == 8'hD5) begin
                        state <= PARSE_ETH; // check for preamble
                    end
                    
                    rd_addr <= rd_addr + 1; // Increment read address only in this state
                end
                PARSE_ETH: begin
                    // shift in data to header buffer
                    if (byte_count < 14) begin
                        header_buffer[byte_count] <= rd_data[31:24];
                        header_buffer[byte_count + 1] <= rd_data[23:16];
                        header_buffer[byte_count + 2] <= rd_data[15:8];
                        header_buffer[byte_count + 3] <= rd_data[7:0];
                        byte_count <= byte_count + 4; // increement byte count
                    end

                    // check if eth type should have been loaded in or not
                    if (byte_count >= 14) begin
                        // check eth type
                        if (header_buffer[12] == 8'h08 && header_buffer[13] == 8'h00) begin
                            valid_ip <= 1;
                            state <= DETECT_OPTIONS; // next state
                            byte_count <= 0; // reset counter so i can reuse the header
                        end else begin
                            state <= DETECT_PREAMBLE; // go back and look for new frame
                        end
                    end
                    rd_addr <= rd_addr + 1; // read next word from ram
                end

                DETECT_OPTIONS: begin
                    // Process four bytes from the word read from RAM
                    if (byte_count < 15) begin
                        header_buffer[byte_count] <= rd_data[31:24];
                        header_buffer[byte_count + 1] <= rd_data[23:16];
                        header_buffer[byte_count + 2] <= rd_data[15:8];
                        header_buffer[byte_count + 3] <= rd_data[7:0];
                        byte_count <= byte_count + 4; // Increment byte_count by 4
                    end

                    // Check if we've processed the IHL from the first byte
                    if (byte_count >= 1) begin
                        // Check IHL (first 4 bits of the first byte)
                        if ((header_buffer[0] & 8'h0F) > 5) begin
                            state <= DETECT_PREAMBLE; // IP header has options, skip packet
                        end else begin
                            state <= PARSE_IP; // Move to IP parsing
                        end
                    end

                    rd_addr <= rd_addr + 1; // Prepare to read the next word from RAM
                end
                PARSE_IP: begin
                    if (byte_count < 15) begin
                        header_buffer[byte_count] <= rd_data[31:24];
                        header_buffer[byte_count + 1] <= rd_data[23:16];
                        header_buffer[byte_count + 2] <= rd_data[15:8];
                        header_buffer[byte_count + 3] <= rd_data[7:0];
                        byte_count <= byte_count + 4; // continue reading data
                    end

                    if (byte_count >= 10) begin
                        if (header_buffer[9] == 8'h11) begin // check for udp
                            valid_udp <= 1;
                            state <= SEND_PAYLOAD; // begin sending payload
                        end else begin
                            state <= DETECT_PREAMBLE; // Not UDP, detect new preamble
                        end
                    end

                    rd_addr <= rd_addr + 1; // read next word from ram
                end

                SEND_PAYLOAD: begin
                    // start streaming output
                    wr_ena <= 1;
                    wr_data <= rd_data; // write to ram
                    wr_addr <= wr_addr + 1;

                    // shift data through
                    preamble_buffer[7] <= preamble_buffer[6];
                    preamble_buffer[6] <= preamble_buffer[5];
                    preamble_buffer[5] <= preamble_buffer[4];
                    preamble_buffer[4] <= preamble_buffer[3];
                    preamble_buffer[3] <= preamble_buffer[2];
                    preamble_buffer[2] <= preamble_buffer[1];
                    preamble_buffer[1] <= preamble_buffer[0];
                    preamble_buffer[0] <= rd_data[7:0];  // update buffer

                    if (preamble_buffer[7] == 8'h55 && preamble_buffer[6] == 8'h55 &&
                        preamble_buffer[5] == 8'h55 && preamble_buffer[4] == 8'h55 &&
                        preamble_buffer[3] == 8'h55 && preamble_buffer[2] == 8'h55 &&
                        preamble_buffer[1] == 8'h55 && preamble_buffer[0] == 8'hD5) begin
                        state <= DETECT_PREAMBLE; // jump back to start
                        wr_ena <= 0; // stop writing to ram
                    end
                    rd_addr <= rd_addr + 1; 
                end

                default: begin
                    state <= DETECT_PREAMBLE; // handle random weirdness
                end
            endcase
        end
    end
endmodule