`default_nettype none
`timescale 1ns/1ps

/*
Written for the FT2232HQ on the CMod A7 board.
- UART Interface supports 7/8 bit data, 1/2 stop bits, and Odd/Even/Mark/Space/No Parity.
- defaulting to 8N1.
- See FTDI AN 120 Aliasing VCP Baud Rates for details, but salient points for valid baudrates.
  - links should be within 3% of the spec'd clock
  - #Mhz basedivided by n + (0.125, 0.25, 0.375, 0.625, 0.5, 0.75, 0.875)
  - TL;DR a few clock cycles won't matter too much if clk > 3*BAUDRATE.
  TODO(avinash)
    - fix ready/valid to be axi4-lite compliant.
*/

module uart_driver(
  clk, rst,
  rx_data, rx_valid,
  tx_data, tx_valid, tx_ready,
  uart_tx, uart_rx
);


// These are set for the CMod A7, modify for different clocks/baudrates!
parameter CLK_HZ = 12_500_000;
parameter BAUDRATE = 115200;
// Depth of synchronizer (measure of MTBF).
parameter SYNC_DEPTH = 3;
// A derived parameter.
localparam OVERSAMPLE = CLK_HZ/BAUDRATE;


// 8N1 - probably shouldn't change this.
parameter DATA_BITS = 8;
parameter PARITY = 0;
parameter STOP_BITS = 1;

input wire clk, rst;
input wire uart_rx;
output logic uart_tx;

input wire [DATA_BITS-1:0] tx_data;
output logic [DATA_BITS-1:0] rx_data;
input wire tx_valid;
output logic rx_valid, tx_ready;

logic [SYNC_DEPTH-1:0] input_buffer;
logic uart_rx_synced;
always_comb uart_rx_synced = input_buffer[SYNC_DEPTH-1];
always_ff@(posedge clk) begin : input_synchronizer
  if(rst) begin
    input_buffer <= -1;
  end else begin
    input_buffer[0] <= uart_rx;
    input_buffer[SYNC_DEPTH-1:1] <= input_buffer[SYNC_DEPTH-2:0];
  end
end

enum logic [1:0] {
  S_IDLE = 0,
  S_START,
  S_DATA,
  S_STOP
} tx_state, rx_state;

logic [31:0] tx_errors, rx_errors;
logic [DATA_BITS-1:0] rx_buffer, tx_buffer;
logic [$clog2(OVERSAMPLE)-1:0] tx_sample_counter, rx_sample_counter;
logic [$clog2(DATA_BITS)-1:0] tx_data_counter, rx_data_counter;

logic rx_mid_cycle;
always_comb begin : sample_point
  rx_mid_cycle = rx_sample_counter == (OVERSAMPLE / 2);
end


always_ff@(posedge clk) begin : rx_fsm
  if(rst) begin
    rx_state <= S_IDLE;
    rx_errors <= 0;
    rx_buffer <= 0;
    rx_sample_counter <= OVERSAMPLE - 1;
    rx_data_counter <= 0;
    rx_data <= 0;
    rx_valid <= 0;
  end else begin
    // Downcounter, reset during idle.
    case(rx_state)
      S_IDLE : rx_sample_counter <= OVERSAMPLE - 1;
      default : begin
        if(rx_sample_counter == 0) rx_sample_counter <= OVERSAMPLE - 1;
        else rx_sample_counter <= rx_sample_counter - 1;
      end
    endcase
    case(rx_state)
      S_IDLE: begin
        if(~uart_rx_synced) begin
          rx_state <= S_START;
          rx_valid <= 0;
        end
      end
      S_START: begin
        if(rx_mid_cycle) begin
          // Optional error check just to make sure we have a start bit here.
          // TODO(avinash) - resetting to idle might make more sense in this case.
          if (uart_rx_synced) begin
            rx_errors <= rx_errors + 1;
          end
        end
        if(rx_sample_counter == 'b0) begin
          rx_state <= S_DATA;
          rx_data_counter <= DATA_BITS - 1;
        end
      end
      S_DATA: begin
        if(rx_mid_cycle) begin
          // $display("@%10t:  <[%1d]=%1b", $time, DATA_BITS-rx_data_counter-1, uart_rx_synced);
          rx_buffer[DATA_BITS-2:0] <= rx_buffer[DATA_BITS-1:1];
          rx_buffer[DATA_BITS-1] <= uart_rx_synced;
          // TODO(avinash) - when covering shift registers explain that this doesn't work: rx_buffer<= {rx_buffer[DATA_BITS-1:1], uart_rx_synced};
        end
        if(rx_sample_counter == 0) begin
          if(rx_data_counter == 0) begin
            rx_state <= S_STOP;
          end else begin
            rx_data_counter <= rx_data_counter - 1;
          end
        end
      end
      S_STOP: begin
        rx_data <= rx_buffer;
        rx_valid <= 1;
        if(rx_sample_counter == 0) begin
          rx_state <= S_IDLE;
        end
      end
      default : rx_state <= S_IDLE;
    endcase
  end 
end // rx_fsm


logic tx_sample_counter_rst;
always_comb begin
  tx_ready = (tx_state == S_IDLE);
  tx_sample_counter_rst = tx_sample_counter == (OVERSAMPLE-1);
  case(tx_state)
    S_IDLE: uart_tx = 1;
    S_START: uart_tx = 0;
    S_DATA: uart_tx = tx_buffer[0];
    S_STOP: uart_tx = 1;
  endcase
end

always_ff @(posedge clk) begin : tx_fsm
  if(rst) begin
    tx_state <= S_IDLE;
    tx_sample_counter <= 0;
    tx_data_counter <= 0;
    tx_buffer <= 0;
  end else begin
    case(tx_state)
      S_IDLE : tx_sample_counter <= 0;
      default : begin
        if(tx_sample_counter_rst) tx_sample_counter <= 0;
        else tx_sample_counter <= tx_sample_counter + 1;
      end
    endcase
    
    // Main fsm
    case(tx_state)
      S_IDLE: begin
        if(tx_valid) begin
          tx_state <= S_START;
          tx_buffer <= tx_data;
        end
      end
      S_START: begin
        if(tx_sample_counter_rst) begin
           tx_state <= S_DATA;
           tx_data_counter <= 0;
        end
      end
      S_DATA: begin
        if(tx_sample_counter_rst) begin
          if(tx_data_counter == (DATA_BITS-1)) begin
            tx_state <= S_STOP;
          end else begin
            tx_buffer[DATA_BITS-1] <= 0;
            tx_buffer[DATA_BITS-2:0] <= tx_buffer[DATA_BITS-1:1];
            tx_data_counter <= tx_data_counter + 1;
          end
        end
      end
      S_STOP: begin
        if(tx_sample_counter_rst) begin
          tx_state <= S_IDLE;
        end
      end
      default : tx_state <= S_IDLE;
    endcase
  end
end

endmodule
