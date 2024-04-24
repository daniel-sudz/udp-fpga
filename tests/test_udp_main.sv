`timescale 1ns / 1ps

module test_udp_main;

    reg main_clk;
    reg main_rst;
    reg [7:0] eth_byte;
    reg input_ready;
    wire valid_ip;
    wire valid_udp;

    udp_main UUT (
        .main_clk(main_clk),
        .main_rst(main_rst),
        .eth_byte(eth_byte),
        .input_ready(input_ready),
        .valid_ip(valid_ip),
        .valid_udp(valid_udp)
    );

    // clock gen
    initial begin
        main_clk = 0;
        forever #5 main_clk = !main_clk; 
    end

    initial begin
        // inputs
        main_rst = 1; input_ready = 0; eth_byte = 0;
        #10 main_rst = 0; 

        // send sample frame
        send_preamble_and_frame;

        #100;  // wait
        $finish;  // end sim
    end

    // this isnt working? idea is to make seng byte function
    task send_byte;
        input [7:0] byte;
        begin
            eth_byte = byte;
            input_ready = 1;
            #10;  // wait
            input_ready = 0;
            #10;  // wait
        end
    endtask

    // function to send whole frame
    task send_preamble_and_frame;
        begin
            send_byte(8'h55);  // preamble
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'hD5);  // sfd

            send_byte(8'hDA);  // mac dest and source
            send_byte(8'hDA);
            send_byte(8'hDA);
            send_byte(8'hDA);
            send_byte(8'hDA);
            send_byte(8'hDA);
            send_byte(8'hAA);
            send_byte(8'hAA);
            send_byte(8'hAA);
            send_byte(8'hAA);
            send_byte(8'hAA);
            send_byte(8'hAA);
            send_byte(8'h08);  // ethtype
            send_byte(8'h00);

            send_byte(8'h45);  // ipv4 payload
            send_byte(8'h00);
        end
    endtask

    initial begin
        $dumpfile("test_udp_main.fst");
        $dumpvars;
    end

endmodule
