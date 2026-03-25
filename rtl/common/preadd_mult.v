`timescale 1ns/1ps

module preadd_mult #(
    parameter WIN   = 16,
    parameter WCOEF = 20
) (
    input  wire signed [WIN-1:0]     sample_a,
    input  wire signed [WIN-1:0]     sample_b,
    input  wire signed [WCOEF-1:0]   coeff,
    output wire signed [WIN:0]       pre_sum,
    output wire signed [WIN+WCOEF:0] product
);

assign pre_sum = $signed(sample_a) + $signed(sample_b);
assign product = $signed(pre_sum) * $signed(coeff);

endmodule
