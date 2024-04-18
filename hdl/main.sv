`timescale 1ns/1ps

module main(mainclk,
btn,
sw,
uart_rxd_out,
uart_txd_in,
led0_b, led0_g, led0_r,
led1_b, led1_g, led1_r,
led2_b, led2_g, led2_r,
led3_b, led3_g, led3_r,
eth_col,
eth_crs,
eth_mdc,
eth_mdio,
eth_ref_clk,
eth_rstn,
eth_rx_clk,
eth_rx_dv,
eth_rxd, //4-bit
eth_rxerr,
eth_tx_clk,
eth_tx_en,
eth_txd //4-bit
);

input wire mainclk;     // 100 MHz
logic [16:0] clk_divider;
logic dataclk;           // 25 MHz
logic uartclk;           // 12.5 MHz
input wire [3:0] btn;   // Buttons
input wire [3:0] sw;    // Switches
logic rst;

always_comb rst = |btn;

always_comb dataclk = clk_divider[1]; // 4x division
always_comb uartclk = clk_divider[2]; // 8x division
always_ff @(posedge mainclk) begin : Clock_Divider
    clk_divider <= clk_divider + 1;
end

//######################        ETHERNET PHY        ############################

// PHY logics
input wire eth_col;         // Collision detect (always 0)
input wire eth_crs;         // Carrier sense (high when recieve medium active)
    output logic eth_mdc;       // Management clock (25 MHz)
    inout eth_mdio;       // Management data
    output logic eth_ref_clk;   // Clock for the chip (25 MHz)
    output logic eth_rstn;      // Reset line
input wire eth_rx_clk;      // Derived RX clock
input wire eth_rx_dv;       // Data valid (when high)
input wire [3:0] eth_rxd;   // RX data
input wire eth_rxerr;       // Data error (when high)
input wire eth_tx_clk;      // Derived TX clock
    output logic eth_tx_en;     // Data ready (when high)
    output logic [3:0] eth_txd; // TX data

// Dump buffer
parameter size = 32;
logic [size-1:0] circle_buffer;
logic [$clog2(size)-1:0] write_pointer;
logic [$clog2(size)-1:0] read_pointer;

// Clocks
always_comb eth_ref_clk = dataclk;
always_comb eth_mdc = dataclk;

// Temporary Straps
assign eth_mdio = (1) ? 1'b1 : 1'bz; // Pulling low starts communication
// Resets on low
always_comb eth_rstn = ~rst; // If any button reads high

always_ff @(posedge eth_rx_clk) begin : Ethernet_Receive
    if(rst) begin
        circle_buffer<='0;
        write_pointer<=0;
    end
    if(eth_rx_dv) begin // TODO: add & not error
        circle_buffer[write_pointer]<=eth_rxd[0];
        circle_buffer[write_pointer+1]<=eth_rxd[1];
        circle_buffer[write_pointer+2]<=eth_rxd[2];
        circle_buffer[write_pointer+3]<=eth_rxd[3];
        write_pointer <= write_pointer + 4;
    end
end

//#########################        OUTPUT        ###############################
input wire uart_txd_in;
output logic uart_rxd_out;
wire tx_ready;
logic tx_valid;
logic [7:0] tx_data;

uart_driver UART(.clk(uartclk), .rst(rst), // reset with rest of system
                .rx_data(), .rx_valid(), // no rx functionality
                .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready),
                .uart_tx(uart_rxd_out), .uart_rx(uart_txd_in)
);

always_ff @(posedge eth_rx_clk) begin : UART_Transmit // run "make usb"
    if(rst) begin
        read_pointer<=0;
    end
    if(tx_ready) begin // TODO: add some sort of error detection for write/read
        tx_valid<=1;
        if(circle_buffer[read_pointer]) begin
            tx_data<=8'd49; // 1
        end else begin
            tx_data<=8'd48; // 0
        end
        read_pointer <= read_pointer + 1;
    end else begin
        tx_valid<=0;
    end
end

//##########################        LEDS        ################################

output logic led0_b,led0_g,led0_r;
output logic led1_b,led1_g,led1_r;
output logic led2_b,led2_g,led2_r;
output logic led3_b,led3_g,led3_r;

logic [31:0] led0_counter;
logic [31:0] led1_counter;
logic [31:0] led2_counter;
logic [31:0] led3_counter;
logic [2:0] global_led_pwm;

always_comb begin : LED_drivers
    if(&global_led_pwm) begin
        if(|sw) begin
            // 0 - Yellow for RX valid
            led0_b = 0;
            led0_g = eth_rx_dv;
            led0_r = eth_rx_dv;

            // 1 - Green for TX ready
            led1_b = 0;
            led1_g = eth_tx_en;
            led1_r = 0;

            // 2 - Red for RX error
            led2_b = 0;
            led2_g = 0;
            led2_r = eth_rxerr;

            // 3 - Pink for medium active
            led2_b = eth_crs;
            led2_g = 0;
            led2_r = eth_crs;
        end else begin
            // 0 - White on reset
            led0_b = rst;
            led0_g = rst;
            led0_r = rst;

            // 1 - Red on MDIO data (low)
            led1_b = 0;
            led1_g = 0;
            led1_r = ~eth_mdio;

            // 2 - Blue on RX clock
            led2_b = eth_rx_clk;
            led2_g = 0;
            led2_r = 0;

            // 3 - Cyan on TX clock
            led3_b = eth_tx_clk;
            led3_g = eth_tx_clk;
            led3_r = 0;
        end
    end else begin
        led0_b = 0;
        led1_b = 0;
        led2_b = 0;
        led3_b = 0;
        led0_g = 0;
        led1_g = 0;
        led2_g = 0;
        led3_g = 0;
        led0_r = 0;
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
    end
end

always_ff @(posedge mainclk ) begin : LED_counters
    led0_counter <= led0_counter + 1;
    led1_counter <= led1_counter + 3;
    led2_counter <= led2_counter + 5;
    led3_counter <= led3_counter + 7;
    global_led_pwm <= global_led_pwm + 1;
end

endmodule