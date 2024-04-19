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

//#######################        FS MACHINE        #############################

enum logic [2:0] {
    E_ERR = 0,
    E_IDLE = 1,
    E_REC = 2,
    U_TX = 3
} eth_state; 

// enum logic [2:0] {
//     U_ERR = 0,
//     U_IDLE = 1,
//     U_TX = 2
// } uart_state; 

logic change_state;
logic eth_start;
logic uart_start;

always_ff @(posedge mainclk) begin : Finite_State_Machine
    if(rst) begin
        eth_state<=E_IDLE;
        // uart_state<=U_IDLE;
    end
    if(eth_state==E_IDLE & change_state) begin
        eth_state<=E_REC;
        eth_start<=0;
        uart_start<=1;
    end else if(eth_state==E_REC & change_state) begin
        eth_state<=U_TX;
        eth_start<=1;
        uart_start<=0;
    end else if(eth_state==U_TX & change_state) begin
        eth_state<=E_IDLE;
        eth_start<=1;
        uart_start<=1;
    end
end

always_comb begin : State_Change
    if(eth_state==E_IDLE) begin
        change_state=eth_rx_dv;
    end
    if(eth_state==E_REC) begin
        change_state=~eth_rx_dv & tx_ready;
    end
    if(eth_state==U_TX) begin
        change_state=0; // TODO: add correct bound
    end
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
    if(rst|eth_start) begin
        // circle_buffer<='0;
        // write_pointer<=0;
        eth_addr<=0;
        wr_data<=0;
        wr_ena<=0;
        ethbitcounter<=0;
    end else begin
        if(eth_state==E_REC & eth_rx_dv) begin // TODO: add & not error
            // circle_buffer[write_pointer]<=eth_rxd[0];
            // circle_buffer[write_pointer+1]<=eth_rxd[1];
            // circle_buffer[write_pointer+2]<=eth_rxd[2];
            // circle_buffer[write_pointer+3]<=eth_rxd[3];
            // write_pointer <= write_pointer + 4;
            wr_data[27:0]<=wr_data[31:4];
            wr_data[31:28]<={eth_rxd[3],eth_rxd[2],eth_rxd[1],eth_rxd[0]};
            ethbitcounter<=ethbitcounter+1;
            if(&ethbitcounter) begin
                eth_addr<=eth_addr+1; // This is one addr desynced
                wr_ena<=1;
            end else begin
                wr_ena<=0;
            end
        end
    end
end

//#######################        BLOCK RAM?        #############################

logic [8:0] addr;
logic [8:0] eth_addr;
logic [8:0] uart_addr;
logic wr_ena;
logic [31:0] wr_data;
wire [31:0] rd_data;
logic [2:0] ethbitcounter;
logic [4:0] uartbitcounter;

always_comb addr = (eth_state==E_REC) ? eth_addr : uart_addr;

bytewise_block_ram RAM(
  .clk(mainclk), .addr(addr), .rd_data(rd_data),
  .wr_ena(wr_ena), .col_ena('1), .wr_data(wr_data)
);

//#########################        OUTPUT        ###############################
input wire uart_txd_in;
output logic uart_rxd_out;
wire tx_ready;
logic tx_valid;
logic [7:0] tx_data;
logic [31:0] read_buffer;

uart_driver UART(.clk(uartclk), .rst(rst), // reset with rest of system
                .rx_data(), .rx_valid(), // no rx functionality
                .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready),
                .uart_tx(uart_rxd_out), .uart_rx(uart_txd_in)
);

always_ff @(posedge eth_rx_clk) begin : UART_Transmit // run "make usb"
    if(rst|uart_start) begin
        uart_addr<=0;
        uartbitcounter<=0;
        read_buffer<=0;
    end else begin
        if(tx_ready) begin // TODO: add some sort of error detection for write/read
            tx_valid<=1;
            // if(circle_buffer[read_pointer]) begin
            if(read_buffer[0]) begin
                tx_data<=8'd49; // 1
            end else begin
                tx_data<=8'd48; // 0
            end
            uartbitcounter<=uartbitcounter+1; //this is also one addr desynced
            if(&uartbitcounter) begin
                uart_addr<=uart_addr+1;
                read_buffer<=rd_data;
            end else begin
                read_buffer[30:0]<=read_buffer[31:1];
            end
        end else begin
            tx_valid<=0;
        end
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