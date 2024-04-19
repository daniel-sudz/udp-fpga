`timescale 1ns/1ps

module tb_udp_main;

    parameter FRAME_WIDTH = 12000; // assuming 1500 byte eth frame width
    reg clk;
    reg rst;
    reg [FRAME_WIDTH-1:0] eth_frame;
    reg frame_valid;
    wire frame_ready;
    wire valid_ipv4;

    // Instantiate the Device Under Test (DUT)
    udp_main dut(
        .main_clk(clk),
        .main_rst(rst),
        .eth_frame(eth_frame),
        .frame_valid(frame_valid),
        .frame_ready(frame_ready),
        .valid_ipv4(valid_ipv4)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Monitor changes on valid_ipv4 and print messages
    always @(posedge clk) begin
        if (valid_ipv4) begin
            $display("%t: IPv4 packet detected.", $time);
        end else if (frame_valid && !valid_ipv4) begin
            $display("%t: Non-IPv4 packet detected.", $time);
        end
    end

    // Use test vectors
    initial begin
        clk = 0;
        rst = 1;
        eth_frame = 0;
        frame_valid = 0;

        // Reset the system
        #20 rst = 0;
        #20 rst = 1;
        #20 rst = 0;

        // Test 1: Valid IPv4 packet
        eth_frame = {48'hAA_BB_CC_DD_EE_FF, // Destination MAC
                     48'h11_22_33_44_55_66, // Source MAC
                     16'h0800,              // IPv4 Ethertype
                     {FRAME_WIDTH-112{1'b0}}}; // Remaining frame bits
        frame_valid = 1'b1;

        #10 frame_valid = 1'b0; // End of frame
        #20;

        // Test 2: Non-IPv4 packet (ARP for example)
        eth_frame = {48'hAA_BB_CC_DD_EE_FF, // Destination MAC
                     48'h11_22_33_44_55_66, // Source MAC
                     16'h0806,              // ARP Ethertype
                     {FRAME_WIDTH-112{1'b0}}}; // Remaining frame bits
        frame_valid = 1'b1;

        #10 frame_valid = 1'b0; // End of frame
        #20;

        // End simulation
        $finish;
    end

endmodule
