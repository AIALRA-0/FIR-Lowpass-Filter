`timescale 1ns/1ps

`include "fir_params.vh"

module fir_l3_pipe (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire signed [3*`FIR_WIN-1:0]      in_vec,
    output wire                              out_valid,
    output reg  signed [3*`FIR_WOUT-1:0]     out_vec
);

wire                              inner_valid;
wire signed [3*`FIR_WOUT-1:0]     inner_vec;

fir_l3_polyphase u_fir_l3_polyphase (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_vec(in_vec),
    .out_valid(inner_valid),
    .out_vec(inner_vec)
);

always @(posedge clk) begin
    if (rst) begin
        out_vec <= {(3*`FIR_WOUT){1'b0}};
    end else if (inner_valid) begin
        out_vec <= inner_vec;
    end
end

valid_pipe #(
    .LATENCY(1)
) u_valid_pipe (
    .clk(clk),
    .rst(rst),
    .in_valid(inner_valid),
    .out_valid(out_valid)
);

endmodule
