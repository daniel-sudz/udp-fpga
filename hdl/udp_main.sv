`timescale 1ns / 1ps

module udp_main(
    input wire main_clk,
    input wire main_rst,
    input wire [7:0] eth_byte,
    input wire input_ready,
    output reg valid_ip,
    output reg valid_udp
);

    // PARAMETERS
    parameter FRAME_WIDTH = 1500; // assuming 1500 bytes
    parameter READ_OFFSET = 4;    // first 4 bytes are potentially grabbed from a different packet

    // BUFFERS & REGISTERS
    reg [7:0] preamble_buffer[6:0]; // store last 7 bytes
    reg [7:0] header_buffer[19:0];  // store header for processing, increased size for potential options
    reg [4:0] byte_count = 0;       // count bytes after SFD
    reg new_frame = 0;              // high if preamble detected 
    integer i; // def iterable

    // STATE DEFINITION
    typedef enum {
        IDLE = 0,
        DETECT_PREAMBLE = 1,
        PARSE_ETH = 2,
        DETECT_OPTIONS = 3,
        PARSE_IP = 4
    } state_t;

    state_t state = IDLE; // initial state

    always_ff @(posedge main_clk) begin
        if (main_rst) begin
            state <= IDLE;
            valid_ip <= 0;
            valid_udp <= 0;
            new_frame <= 0;
            byte_count <= 0;
            // on reset, clear the buffers
            for (i = 0; i < 20; i = i + 1) begin
                header_buffer[i] <= 8'd0;
            end
        end else if (input_ready) begin
            // shift in data through preamble buffer
            preamble_buffer[6] <= preamble_buffer[5];
            preamble_buffer[5] <= preamble_buffer[4];
            preamble_buffer[4] <= preamble_buffer[3];
            preamble_buffer[3] <= preamble_buffer[2];
            preamble_buffer[2] <= preamble_buffer[1];
            preamble_buffer[1] <= preamble_buffer[0];
            preamble_buffer[0] <= eth_byte;

            case (state)
                IDLE: begin
                    state <= DETECT_PREAMBLE;
                end

                DETECT_PREAMBLE: begin
                    // check if last 7 bytes match preamble
                    if (preamble_buffer[6] == 8'h55 && preamble_buffer[5] == 8'h55 &&
                        preamble_buffer[4] == 8'h55 && preamble_buffer[3] == 8'h55 &&
                        preamble_buffer[2] == 8'h55 && preamble_buffer[1] == 8'h55 &&
                        preamble_buffer[0] == 8'hD5) begin
                        new_frame <= 1;
                        byte_count <= 0;
                        state <= PARSE_ETH; // transition to PARSE_ETH if match found
                    end
                end

                PARSE_ETH: begin
                    if (new_frame) begin
                        new_frame <= 0; // Reset new_frame after detecting it
                    end else if (byte_count > 0) begin
                        if (byte_count > 1) begin
                            header_buffer[byte_count - 2] <= eth_byte;
                        end
                        byte_count <= byte_count + 1;
                        if (byte_count == 14) begin  // check ethertype
                            if (header_buffer[11] == 8'h08 && header_buffer[12] == 8'h00) begin
                                valid_ip <= 1;
                                state <= DETECT_OPTIONS;  // move to detect options
                                byte_count <= 0;  // Reset byte count for IPv4 header parsing
                            end else
                                state <= IDLE;  // not an IP packet, return to idle
                        end
                    end
                end

                DETECT_OPTIONS: begin
                    if (byte_count < 20) begin  // parse up to the first 20 bytes of the IPv4 frame
                        header_buffer[byte_count] <= eth_byte;
                        byte_count <= byte_count + 1;
                        if (byte_count == 1 && (header_buffer[0] & 4'h0F) > 5) begin // check value of ihl
                            state <= IDLE;  // skip all packets with options
                        end
                    end
                end

                PARSE_IP: begin
                    //add stuff
                end

                default: state <= IDLE; // default case
            endcase
        end
    end

endmodule
