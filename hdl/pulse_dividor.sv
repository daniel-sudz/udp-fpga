`timescale 1ns/1ps
`default_nettype none

/* Divides clk period into clk/ticks period assuming period is even
*/
module pulse_dividor(clk, ticks, rst, out);
    parameter N = 32;

    input wire clk;
    input wire rst;
    input wire [N-1:0] ticks;

    output logic out = 0;

    logic [N-1:0] counter = 0;

    always_ff @(posedge clk) begin
        if(rst) begin
            out <= 1'b1;
        end else begin
            if(counter == ((ticks>>1)-1)) begin
                out <= ~out;
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end

    end

endmodule