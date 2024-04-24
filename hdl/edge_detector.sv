`timescale 1ns/1ps

module edge_detector(clk, rst, in, positive_edge, negative_edge);

input wire clk, rst, in;
output logic positive_edge, negative_edge;

// SOLUTION START
logic last_in; // Flip flop to store last input value.

always @(posedge clk) begin
  if(rst) begin
    last_in <= 0;
  end else begin
    last_in <= in;
  end
end

// This is a Mealy machine since the output states are combinational on the input.
// You'll see a waveform (that will still work) that is only high for half a clock cycle
// in the testbench, that is okay!
always_comb begin : mealy_output_logic
  positive_edge = in & ~last_in;
  negative_edge = ~in & last_in;
end
// SOLUTION END

endmodule