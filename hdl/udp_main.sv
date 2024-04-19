`timescale 1ns/1ps

module udp_main(main_clk, main_rst,eth_frame,frame_valid,frame_ready,valid_ipv4);
parameter FRAME_WIDTH = 12000; // assuming 1500 byte eth frame width
input wire main_clk;
input wire main_rst;
input wire [FRAME_WIDTH-1:0] eth_frame;
input wire frame_valid;
output reg frame_ready;
output reg valid_ipv4;

wire [47:0] eth_mac_dest;
wire [47:0] eth_mac_src;
wire [15:0] eth_type;
wire [31:0] eth_frc;

assign eth_type = eth_frame[103:96];

always_ff @(posedge main_clk) begin
    if (main_rst) begin
        frame_ready <= 1'b1;   // ready for frame
        valid_ipv4 <= 1'b0;    // reset validity
    end else begin
        frame_ready <= 1'b0;
        if (frame_ready) begin
            valid_ipv4 <= (eth_type == 16'h0800); // looking for 0x0800 ethertype
        end else begin
            valid_ipv4 <= 1'b0; // not valid ipv4
        end
    end
end

endmodule