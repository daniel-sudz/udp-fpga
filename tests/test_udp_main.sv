`timescale 1ns/1ps

module tb_udp_main;

    parameter FRAME_WIDTH = 12000; // standard frame width
    reg main_clk;
    reg main_rst;
    reg [FRAME_WIDTH-1:0] eth_frame;
    reg frame_start;
    wire valid_ip;

    udp_main #(.FRAME_WIDTH(FRAME_WIDTH)) uut (
        .main_clk(main_clk),
        .main_rst(main_rst),
        .eth_frame(eth_frame),
        .frame_start(frame_start),
        .valid_ip(valid_ip)
    );

    // 25mhz clock because idk
    initial begin
        main_clk = 0;
        forever #20 main_clk = ~main_clk; // manual assertions for clock
    end

    initial begin
        main_rst = 1;
        eth_frame = 0;
        frame_start = 0;

        #40;
        main_rst = 0;
        
        // valid packet
        eth_frame[111:96] = 16'h0800; // 0x0800 is ipv4 ethtype
        frame_start = 1'b1;
        #40 frame_start = 1'b0;

        #100;

        // arp packet (bad)
        eth_frame[111:96] = 16'h0806; // arp is 0x0806
        frame_start = 1'b1;
        #40 frame_start = 1'b0;

        #100;

        $finish;
    end

    initial begin
        $dumpfile("test_udp_main.fst");
        $dumpvars;
    end

endmodule
