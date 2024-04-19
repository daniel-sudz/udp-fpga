`default_nettype none
`timescale 1ns/1ps

// Based on UG901 - The Vivado Synthesis Guide.

module bytewise_block_ram(
  clk, addr, rd_data, wr_ena, col_ena, wr_data
);

parameter W = 32; // Width of each row of  the memory
localparam C=W/8;
parameter L = 375; // Length of the memory
parameter INIT = "zeros.memh";
parameter WRITE_FIRST=1;

input wire clk;
input wire [$clog2(L)-1:0] addr;
output logic [W-1:0] rd_data;
input wire wr_ena;
input wire [C-1:0] col_ena;
input logic [W-1:0] wr_data;

logic [W-1:0] ram [0:L-1];
initial begin
  if(W % 8 != 0) begin
    $display("ERROR: bytewise blockram must have a width divisible by 8");
    $finish;
  end
  $display("###########################################");
  $display("# Initializing block ram from file %s.", INIT);
  $display("###########################################");
  $readmemh(INIT, ram); // Initializes the RAM with the values in the init file.
end

// Create one port per column in memory.
genvar i;
generate for(i = 0; i < C; i++) begin
  always_ff @(posedge clk) begin : block_ram_ports
    if(wr_ena & col_ena[i]) begin
      if(~WRITE_FIRST)
        rd_data[i*8 +: 8] <= ram[addr][i*8 +: 8];
      ram[addr][i*8 +: 8] <= wr_data[i*8 +: 8];
      if(WRITE_FIRST)
        rd_data[i*8 +: 8] <= ram[addr][i*8 +: 8];
    end
  end
end endgenerate

task dump_memory(string file);
  $writememh(file, ram);
endtask

endmodule
