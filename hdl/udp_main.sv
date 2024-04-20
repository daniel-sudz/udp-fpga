    `timescale 1ns/1ps

    module udp_main(main_clk, main_rst, eth_byte, valid_ip,valid_udp,input_ready);

        //PARAMETERS
        parameter FRAME_WIDTH = 1500; // assuming 1500 bytes (maybe calculate)
        parameter READ_OFFSET = 4; // first 4 bytes are potentialy grabbed from diff packet

        // INPUTS
        input wire main_clk;
        input wire main_rst;
        input wire [7:0] eth_byte;
        input wire input_ready;

        // OUTPUTS
        output reg valid_ip;
        output reg valid_udp;


        // other intermediaries
        wire new_frame; // high if preamble detected

        // BUFFERS & REGISTERS
        reg [7:0] preamble_buffer[6:0];  // store last 7 bytes
        reg [7:0] header_buffer[13:0];   // store header for processing
        reg [4:0] byte_count = 0;        // count bytes after SFD

        // setup states
        typedef enum {
            IDLE = 0,
            DETECT_PREAMBLE = 1,
            PARSE_ETH = 2,
            PROCESS_PAYLOAD = 3,
        } state_t;

        state_t state = IDLE; // start state is idle


        always_ff @(posedge main_clk) begin
            if (main_rst) begin
                state <= IDLE;
                valid_frame = 0; // no preamble detected
                // on reset, clear the buffer and go to idle state
                preamble_buffer[0] <= 8'd0;
                preamble_buffer[1] <= 8'd0;
                preamble_buffer[2] <= 8'd0;
                preamble_buffer[3] <= 8'd0;
                preamble_buffer[4] <= 8'd0;
                preamble_buffer[5] <= 8'd0;
                preamble_buffer[6] <= 8'd0;
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
                        // check if last 7 bytes match preamble.
                        if (preamble_buffer[6] == 8'h55 && preamble_buffer[5] == 8'h55 &&
                            preamble_buffer[4] == 8'h55 && preamble_buffer[3] == 8'h55 &&
                            preamble_buffer[2] == 8'h55 && preamble_buffer[1] == 8'h55 &&
                            preamble_buffer[0] == 8'hD5) begin
                            new_frame <= 1;
                            byte_count <= 0;
                            state <= PARSE_HEADERS;  // if match found, we are at frame start.
                        end
                    end

                    PARSE_ETH: begin
                        if (byte_count < 14) begin
                            // Buffer bytes starting after SFD, skipping the first byte
                            if (byte_count > 0) header_buffer[byte_count - 1] <= eth_byte;
                            byte_count <= byte_count + 1;
                        end else {
                            // check ethertype bytes (13 and 14)
                            if (header_buffer[12] == 8'h08 && header_buffer[13] == 8'h00) {
                                valid_ip <= 1;
                                state <= PROCESS_PAYLOAD;  // process frame
                            } else {
                                // skip frame and wait for next one
                                state <= IDLE;
                            }
                        end
                    end

                    default: state <= IDLE; // send to idle state on any weird behaviour
                endcase
            end
        end

    endmodule

