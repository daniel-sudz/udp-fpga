`timescale 1ns/1ps

module udp_main(main_clk, main_rst, eth_frame, valid_ip,frame_start);
    parameter FRAME_WIDTH = 12000; // assuming 1500 byte eth frame width
    parameter MAC_WIDTH = 48;
    input wire main_clk;
    input wire main_rst;
    input wire [FRAME_WIDTH-1:0] eth_frame;
    input wire frame_start;
    output reg valid_ip;

    wire [47:0] eth_mac_dest;
    wire [47:0] eth_mac_src;
    wire [15:0] eth_type;
    output wire [31:0] eth_frc;
    output wire [3:0] ip_version;


   // setup state machine for header parsing
    typedef enum {
        IDLE = 0,
        PARSE_HEADERS = 1,
        SKIP_FRAME = 2
    } state_t;

    state_t state = IDLE; // start state is idle

    // grab ethtype and ip version
    assign eth_type = eth_frame[111:96];

    // frame handling state machine
    always_ff @(posedge main_clk) begin
        if (main_rst) begin
            state <= IDLE;  // on reset return to idle
            valid_ip <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (frame_start)  // when frame is started:
                        state <= PARSE_HEADERS;
                end
                PARSE_HEADERS: begin
                    // check ethtype for 0x0800
                    if (eth_type == 16'h0800) begin
                        valid_ip <= 1'b1;
                        state <= IDLE;
                    end else begin
                        valid_ip <= 1'b0;
                        state <= SKIP_FRAME;  // skip frame
                    end
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

