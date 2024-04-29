`timescale 1ns/1ps

// Based on UG901 - The Vivado Synthesis Guide

module block_ram(clk, rd_addr, rd_data, wr_addr, wr_ena, wr_data, rd_addr2, rd_data2);

parameter W = 32; // number of rows of the memory
parameter L = 350; // Length of the memory row
parameter INIT = "zeros.memh";

input wire clk;
input wire [$clog2(L)-1:0] wr_addr, rd_addr, rd_addr2;
output logic [W-1:0] rd_data, rd_data2;
input wire wr_ena;
input logic [W-1:0] wr_data;

logic [W-1:0] ram [0:L-1];
initial begin
  $display("Initializing block ram from file %s.", INIT);
  $readmemh(INIT, ram); // Initializes the RAM with the values in the init file.
end

always_ff @(posedge clk) begin : synthesizable_rom
  rd_data <= ram[rd_addr];
  rd_data2 <= ram[rd_addr2];
  if(wr_ena) begin
    ram[wr_addr] <= wr_data;
  end
end

task dump_memory(string file);
  $writememh(file, ram);
endtask


endmodule
