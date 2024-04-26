`default_nettype none
`timescale 1ns/1ps

// Outputs a pulse generator with a period of "ticks".
// outt should go high for one cycle ever "ticks" clocks.

module pulse_generator(clk, rst, ena, ticks, out);

parameter N = 8;
input wire clk, rst, ena;
input wire [N-1:0] ticks;
output logic out;

// SOLUTION START

// Uncomment one of the following defines to try different solutions.

`define BEHAVIORAL_SOLUTION
// `define STRUCTURAL_UP_COUNTER
// `define STRUCTURAL_DOWN_COUNTER
`ifdef BEHAVIORAL_SOLUTION
logic [N-1:0] counter;
logic count_done;
always_comb begin : comparator_logic
  count_done = (counter >= ticks);
end

always_ff @(posedge clk) begin : counter_logic
  if(rst) begin
    counter <= 0;
  end
  else if (ena) begin
    if (count_done) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end
end

always_comb begin : output_logic
  out = count_done & ena;
end 
`endif // BEHAVIORAL_SOLUTION

`ifdef STRUCTURAL_UP_COUNTER
wire [N-1:0] counter, next_counter;
logic counter_rst;
wire count_done;

adder_n #(.N(N)) ADDER(
  .a(counter), .b(1), .c_in(1'b0), .sum(next_counter), .c_out()
);

comparator_eq #(.N(N)) COMPARATOR(
  .a(next_counter), .b(ticks), .out(count_done)
);

always_comb begin
  out = count_done & ena;
  counter_rst = count_done | rst;
end

register #(.N(N)) COUNTER_REGISTER(
  .clk(clk), .rst(counter_rst), .ena(1'b1), .d(next_counter), .q(counter)
);

`endif // STRUCTURAL_UP_COUNTER

`ifdef STRUCTURAL_DOWN_COUNTER
wire [N-1:0] counter, next_counter;
logic counter_rst;
wire count_done;

adder_n #(.N(N)) SUBTRACTOR(
  .a(counter), .b(-1), .c_in(0), .sum(next_counter), .c_out()
);

comparator_eq #(.N(N)) COMPARATOR(
  .a(counter), .b(1), .out(count_done)
);

logic [N-1:0] counter_d;
always_comb begin
  out = count_done & ena;
  counter_rst = count_done | rst;
  counter_d = counter_rst ? ticks : next_counter;
end

register #(.N(N)) COUNTER_REGISTER(
  .clk(clk), .rst(rst), .ena(1'b1), .d(counter_d), .q(counter)
);

`endif // STRUCTURAL_DOWN_COUNTER



// SOLUTION END

endmodule
