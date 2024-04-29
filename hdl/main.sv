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
eth_txd, //4-bit
mclk, // I2S2
lrclk,
sclk,
sdin
);

// General
input wire mainclk;     // 100 MHz | 90.24 MHz
logic [16:0] clk_divider;
logic dataclk;           // 25 MHz | 22.56 MHz
logic uartclk;           // 12.5 MHz | 11.28 MHz
input wire [3:0] btn;   // Buttons
input wire [3:0] sw;    // Switches
logic rst;

// Output
input wire uart_txd_in;
output logic uart_rxd_out;
wire tx_ready;
logic tx_valid;
logic [7:0] tx_data;
logic [31:0] read_buffer;
logic [31:0] pb_read_buffer;

always_comb rst = |btn[3:1];

always_comb dataclk = clk_divider[1]; // 4x division
always_comb uartclk = clk_divider[2]; // 8x division
always_ff @(posedge mainclk) begin : Clock_Divider
    clk_divider <= clk_divider + 1;
end

//##########################        I2S2        ################################

output logic mclk;
output logic lrclk;
output logic sclk;
output logic sdin;

logic [23:0] wch1, wch2;
parameter sclk_divider = 1; 
logic [sclk_divider:0] sclk_counter; //4x less
parameter lrclk_divider = 7;
logic [lrclk_divider:0] lrclk_counter; //256x less
parameter mclk_divider = 2; //2
logic [mclk_divider:0] mclk_counter; //11.28 MHz

//Clock divider
always_comb begin
  sclk = sclk_counter[sclk_divider];
  mclk = mclk_counter[mclk_divider];
  lrclk = lrclk_counter[lrclk_divider];
end

// 11.28 MHz clock
wire clk_feedback;
MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),
  .CLKFBOUT_MULT_F(6.375), //2.0 to 64.0 in increments of 0.125
  .CLKIN1_PERIOD(10.0),
  .CLKOUT0_DIVIDE_F(28.250), // Divide amount for CLKOUT0 (1.000-128.000).
  .DIVCLK_DIVIDE(1), // Master division value (1-106)
  .CLKOUT0_DUTY_CYCLE(0.5),.CLKOUT0_PHASE(0.0),
  .STARTUP_WAIT("FALSE") // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
.CLKOUT0(mclk),
.CLKIN1(mainclk),
.PWRDWN(0),
.RST(rst),
.CLKFBOUT(clk_feedback),
.CLKFBIN(clk_feedback)
);
// always_ff @(posedge mainclk) begin : main_clock
//     if (rst) begin
//       mclk_counter <= 0;
//     end else begin
//         if(&mclk_counter) begin
//         mclk_counter <= 0;
//       end
//       else begin
//         mclk_counter <= mclk_counter + 1;
//       end
//     end
// end 

//Clock counters
always_ff @(posedge mclk) begin : clocks_and_dividers 
  if (rst) begin
      sclk_counter <= 0;
      lrclk_counter <= 0;
  end
  else begin
      if(&sclk_counter) begin
        sclk_counter <= 0;
      end
      else begin
        sclk_counter <= sclk_counter + 1;
      end
      
      if(&lrclk_counter) begin
        lrclk_counter <= 0;
      end
      else begin
        lrclk_counter <= lrclk_counter + 1;
      end    
  end
end

always_comb begin
    wch1={pb_read_buffer[3:0], pb_read_buffer[7:4], pb_read_buffer[11:8], pb_read_buffer[15:12], 8'b0};
    wch2={pb_read_buffer[19:16], pb_read_buffer[23:20], pb_read_buffer[27:24], pb_read_buffer[31:28], 8'b0};
end

logic [8:0] pb_endaddr, pb_startaddr, check_addr;
logic pb_reset, posreset, negreset, shot;
logic [31:0] check;
edge_detector S(.clk(lrclk), .rst(rst), .in(pb_reset), .positive_edge(posreset), .negative_edge(negreset)); //SCLK edge detector relative to mclk


always_ff @(posedge lrclk) begin : I2S2_Transmit
    if(rst|posreset|~(&(~check))) begin
        if(sw[1]) begin
            check_addr<=9'd2;
            pb_startaddr<=9'd13;//9'd13; // 52 bytes header
            pbbitcounter<=0; //0
            pb_endaddr<=9'd312;//9'd312; // end of message 1500 bytes
            // if(&(~check)) begin
            //     pb_read_buffer<=rd_data;
            // end
            pb_addr<=pb_startaddr;
            shot<=1;
        end else begin
            pb_addr<=9'd0; // 50 bytes offset
            pbbitcounter<=0;
            pb_endaddr<=9'd375; // end of message
            shot<=1;
        end
    end else begin
        // if(eth_state==PLAY_BACK) begin
            if(pb_addr<=pb_endaddr & shot) begin
                if(pbbitcounter) begin
                    pb_addr<=pb_addr+1;
                    pb_read_buffer<=rd_data;
                end
            end else begin
                pb_addr<=pb_startaddr;
                shot<=0;
            end
            if(~sw[1] & pb_addr>pb_endaddr) begin
                pb_addr<=0;
            end
            pbbitcounter<=~pbbitcounter;
        // end
    end
end

i2s2 AUDIO(.rch1(), .rch2(), .wch1(wch1), .wch2(wch2), .datain(), .dataout(sdin),
            .valid(), .lrclk(lrclk), .sclk(sclk), .mclk(mclk), .rst(rst));

//#######################        FS MACHINE        #############################

enum logic [2:0] {
    E_ERR = 0,
    E_IDLE = 1,
    E_REC = 2,
    U_TX = 3,
    PLAY_BACK = 4
} eth_state; 

// enum logic [2:0] {
//     U_ERR = 0,
//     U_IDLE = 1,
//     U_TX = 2
// } uart_state; 

logic change_state;
logic eth_start;
logic uart_start;
logic pb_start;

logic one_shot;
logic skip_uart;

always_ff @(posedge mainclk) begin : Finite_State_Machine
    if(rst) begin
        eth_state<=E_IDLE;
        one_shot<=1;
        skip_uart<=0;
        eth_start<=1;
        uart_start<=1;
        pb_start<=1;
        pb_reset<=1;
        // uart_state<=U_IDLE;
    end
    if(eth_state==E_IDLE & change_state) begin
        eth_state<=E_REC;
        eth_start<=0;
        uart_start<=1;
        pb_start<=1;
        one_shot<=0;
        pb_reset<=0;
    end else if(eth_state==E_REC & change_state) begin
        if(skip_uart) begin
            eth_state<=E_IDLE;
            eth_start<=1;
            uart_start<=1;
            pb_start<=0;
            pb_reset<=1;
        end else begin
            eth_state<=U_TX;
            eth_start<=1;
            uart_start<=0; 
            pb_start<=1;
            pb_reset<=1;
        end
    end else if(eth_state==U_TX & change_state) begin
        eth_state<=E_IDLE;
        eth_start<=1;
        uart_start<=1;
        pb_start<=0;
        pb_reset<=0;
    end else if(eth_state==PLAY_BACK & change_state) begin
        eth_state<=E_IDLE;
        eth_start<=1;
        uart_start<=1;
        pb_start<=1;
        pb_reset<=0;
    end else if(eth_state==E_ERR) begin
        eth_state<=E_IDLE;
    end
    if(sw[0]) begin
        one_shot<=1;
        skip_uart<=1;
    end else begin
        one_shot<=btn[0];
        skip_uart<=1;
    end
end

always_comb begin : State_Change
    if(eth_state==E_IDLE & one_shot) begin
        change_state=eth_rx_dv;
    end else if(eth_state==E_REC) begin
        change_state=~eth_rx_dv & tx_ready;
    end else if(eth_state==U_TX) begin
        // change_state=(uart_addr>=9'd375); // TODO: add correct bound (375?)
        change_state=1;
    end else if(eth_state==PLAY_BACK) begin
        // change_state=(pb_addr>=9'd375);
        change_state=1;
    end else begin
        change_state=0;
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
// parameter size = 32;
// logic [size-1:0] circle_buffer;
// logic [$clog2(size)-1:0] write_pointer;
// logic [$clog2(size)-1:0] read_pointer;

// Pair flipping (don't ask me why this is or why this isn't we do not ask)
logic [31:0] eth_wr_data;
always_comb begin
    wr_data[31:28]=eth_wr_data[27:24];
    wr_data[27:24]=eth_wr_data[31:28];

    wr_data[23:20]=eth_wr_data[19:16];
    wr_data[19:16]=eth_wr_data[23:20];

    wr_data[15:12]=eth_wr_data[11:8];
    wr_data[11:8]=eth_wr_data[15:12];

    wr_data[7:4]=eth_wr_data[3:0];
    wr_data[3:0]=eth_wr_data[7:4];
end

// Clocks
always_comb eth_ref_clk = dataclk;
always_comb eth_mdc = dataclk;

// Temporary Straps
assign eth_mdio = (1) ? 1'b1 : 1'bz; // Pulling low starts communication
// Resets on low
always_comb eth_rstn = ~rst; // If any button reads high

logic increment, posincrement;
edge_detector INCREMENT_ED(.clk(mainclk), .rst(rst), .in(increment), .positive_edge(posincrement), .negative_edge()); //SCLK edge detector relative to mclk

always_ff @(posedge mainclk) begin : Ethernet_Address
    if(rst|eth_start) begin
        eth_addr<='1;
    end else begin
        if(posincrement) begin
            eth_addr<=eth_addr+1;
        end
    end
end

always_ff @(posedge eth_rx_clk) begin : Ethernet_Receive
    if(rst|eth_start) begin
        // circle_buffer<='0;
        // write_pointer<=0;
        // eth_addr<='1;
        eth_wr_data<=0;
        wr_ena<=0;
        ethbitcounter<=0;
        increment<=0;
    end else begin
        if(eth_state==E_REC & eth_rx_dv) begin // TODO: add & not error
            // circle_buffer[write_pointer]<=eth_rxd[0];
            // circle_buffer[write_pointer+1]<=eth_rxd[1];
            // circle_buffer[write_pointer+2]<=eth_rxd[2];
            // circle_buffer[write_pointer+3]<=eth_rxd[3];
            // write_pointer <= write_pointer + 4;
            eth_wr_data[27:0]<=eth_wr_data[31:4];
            eth_wr_data[31:28]<={eth_rxd[3],eth_rxd[2],eth_rxd[1],eth_rxd[0]};
            ethbitcounter<=ethbitcounter+1;
            if(&ethbitcounter) begin
                // eth_addr<=eth_addr+1; // This is one addr desynced
                increment<=1;
                // (should be fixed via eth_addr start value)
                if(sw[1]) begin
                    wr_ena<=1;
                end
            end else begin
                wr_ena<=0; 
                increment<=0;
            end
        end
    end
end

//#######################        BLOCK RAM?        #############################

logic [8:0] wr_addr;
logic [8:0] rd_addr;
logic [8:0] eth_addr;
logic [8:0] uart_addr;
logic [8:0] pb_addr;
logic wr_ena;
logic [31:0] wr_data;
wire [31:0] rd_data;
logic [2:0] ethbitcounter;
logic [4:0] uartbitcounter;
logic pbbitcounter;

always_comb begin
    if(eth_state==E_REC) begin
        wr_addr = eth_addr;
    end else if(eth_state==U_TX) begin
        rd_addr = uart_addr;
    end  else if(eth_state==PLAY_BACK) begin
        rd_addr = pb_addr;
    end else begin
        rd_addr = pb_addr;
    end
end

block_ram #(.INIT("deadbeef.memh")) RAM(
  .clk(mainclk), .rd_addr(rd_addr), .rd_data(rd_data),
  .wr_addr(wr_addr), .wr_ena(wr_ena), .wr_data(wr_data), .rd_addr2(check_addr), .rd_data2(check)
);

block_ram #(.INIT("deadbeef.memh")) RAM2(
  .clk(mainclk), .rd_addr(rd_addr), .rd_data(rd_data),
  .wr_addr(wr_addr), .wr_ena(wr_ena), .wr_data(wr_data), .rd_addr2(check_addr), .rd_data2(check)
);

//#########################        OUTPUT        ###############################

uart_driver UART(.clk(uartclk), .rst(rst), // reset with rest of system
                .rx_data(), .rx_valid(), // no rx functionality
                .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready),
                .uart_tx(uart_rxd_out), .uart_rx(uart_txd_in)
);

always_ff @(posedge uartclk) begin : UART_Transmit // run "make usb"
    // TODO: nasty bug that occurs when running too fast causes whole thing to freeze
    if(rst|uart_start) begin
        uart_addr<=0;
        uartbitcounter<=5'd3;
        read_buffer<=32'h55555555; //should fix 0 print error
        tx_data<=0;
        tx_valid<=0;
    end else begin
        if(eth_state==U_TX & tx_ready & ~tx_valid) begin // TODO: add some sort of error detection for write/read
            tx_valid<=1;
            // if(circle_buffer[read_pointer]) begin
            // BINARY
            // if(read_buffer[0]) begin
            //     tx_data<=8'd49; // 1
            // end else begin
            //     tx_data<=8'd48; // 0
            // end
            // uartbitcounter<=uartbitcounter+1; //this is also one addr desynced
            // if(&uartbitcounter) begin
            //     uart_addr<=uart_addr+1;
            //     read_buffer<=rd_data;
            // end else begin
            //     read_buffer[30:0]<=read_buffer[31:1];
            // end
            // HEX
            case(read_buffer[3:0])
                4'd0: tx_data<=8'h30;
                4'd1: tx_data<=8'h31;
                4'd2: tx_data<=8'h32;
                4'd3: tx_data<=8'h33;
                4'd4: tx_data<=8'h34;
                4'd5: tx_data<=8'h35;
                4'd6: tx_data<=8'h36;
                4'd7: tx_data<=8'h37;
                4'd8: tx_data<=8'h38;
                4'd9: tx_data<=8'h39;
                4'd10: tx_data<=8'h61;
                4'd11: tx_data<=8'h62;
                4'd12: tx_data<=8'h63;
                4'd13: tx_data<=8'h64;
                4'd14: tx_data<=8'h65;
                4'd15: tx_data<=8'h66;
            endcase
            uartbitcounter<=uartbitcounter+4;
            if(uartbitcounter==5'd3) begin
                uart_addr<=uart_addr+1;
            end
            if(&uartbitcounter) begin
                read_buffer<=rd_data;
            end else begin
                read_buffer[27:0]<=read_buffer[31:4];
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
        if(sw[3]) begin
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
        end else if(sw[2]) begin
            // 0 - Green for IDLE
            led0_b = 0;
            led0_g = eth_state==E_IDLE;
            led0_r = 0;

            // 1 - Yellow for E_REC
            led1_b = 0;
            led1_g = eth_state==E_REC;
            led1_r = eth_state==E_REC;

            // 2 - Red for U_TX
            led2_b = 0;
            led2_g = 0;
            led2_r = eth_state==U_TX;

            // // 3 - Pink for PLAY_BACK
            // led3_b = eth_state==PLAY_BACK;
            // led3_g = 0;
            // led3_r = eth_state==PLAY_BACK;

            // 3 - Pink for posreset
            led3_b = posreset;
            led3_g = 0;
            led3_r = posreset;
        end else begin
            // 0 - White on reset
            led0_b = rst;
            led0_g = rst;
            led0_r = rst;

            // 1 - Red on error state
            led1_b = eth_state==E_ERR;
            led1_g = eth_state==E_ERR;
            led1_r = eth_state==E_ERR;

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

// print("\n".join(["%02x"%ord("%01x"%i) for i in range(16)]))
// 30
// 31
// 32
// 33
// 34
// 35
// 36
// 37
// 38
// 39
// 61
// 62
// 63
// 64
// 65
// 66