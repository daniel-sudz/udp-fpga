`timescale 1ns / 1ps

module udp_main(
    input wire main_clk,
    input wire main_rst,
    input wire [7:0] eth_byte,
    input wire input_ready,
    output reg valid_ip,
    output reg valid_udp,
    output reg [7:0] udp_byte
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
        DETECT_PREAMBLE = 0,
        PARSE_ETH = 1,
        DETECT_OPTIONS = 2,
        PARSE_IP = 3,
        SEND_PAYLOAD = 4
    } state_t;

    state_t state = DETECT_PREAMBLE; // initial state

    always_ff @(posedge main_clk) begin
        if (main_rst) begin
            state <= DETECT_PREAMBLE;
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
                        if (byte_count < 14 ) begin
                            header_buffer[byte_count - 1] <= eth_byte;
                        end else if (byte_count == 14) begin  // check ethertype
                            if (header_buffer[11] == 8'h08 && header_buffer[12] == 8'h00) begin
                                valid_ip <= 1;
                                state <= DETECT_OPTIONS;  // move to detect options
                                byte_count <= 0;  // reset byte count (using same header...)
                            end else
                                state <= DETECT_PREAMBLE;  // not an IP packet, return to idle
                        end
                    end
                    byte_count <= byte_count + 1;
                end

                DETECT_OPTIONS: begin
                    if (byte_count < 20) begin  // parse up to the first 20 bytes of the IPv4 frame
                        header_buffer[byte_count] <= eth_byte;
                        byte_count <= byte_count + 1;
                        if (byte_count == 1 && (header_buffer[0] & 4'h0F) > 5) begin // check value of ihl
                            state <= DETECT_PREAMBLE;  // skip all packets with options
                        end
                        state <= PARSE_IP;
                    end
                end

                PARSE_IP: begin
                    if (byte_count < 20) begin  // keep updating buffer
                        header_buffer[byte_count] <= eth_byte;
                        byte_count <= byte_count + 1;
                    end
                    if (byte_count == 10 && header_buffer[9] == 8'h11) begin // udp check
                        valid_udp <= 1;
                        state <= SEND_PAYLOAD;
                    end else if (byte_count == 10) begin
                        state <= DETECT_PREAMBLE; // skip if not udp
                    end
                end

                SEND_PAYLOAD: begin
                    if (byte_count > 20) begin
                        udp_byte <= eth_byte; // stream output
                    end
                    byte_count <= byte_count + 1;
                    // questionable... need to think about better way to do this since it copies first state...
                    if (preamble_buffer[6] == 8'h55 && preamble_buffer[5] == 8'h55 &&
                        preamble_buffer[4] == 8'h55 && preamble_buffer[3] == 8'h55 &&
                        preamble_buffer[2] == 8'h55 && preamble_buffer[1] == 8'h55 &&
                        preamble_buffer[0] == 8'hD5) begin
                        byte_count <= 0;
                        new_frame <= 1;
                        state <= PARSE_ETH; 
                    end
                end

                

                default: state <= DETECT_PREAMBLE; // default case
            endcase
        end
    end

endmodule
