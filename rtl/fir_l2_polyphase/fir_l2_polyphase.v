`timescale 1ns/1ps

`include "fir_params.vh"
`include "fir_polyphase_params.vh"

module fir_l2_polyphase (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire signed [2*`FIR_WIN-1:0]      in_vec,
    output wire                              out_valid,
    output wire signed [2*`FIR_WOUT-1:0]     out_vec
);

localparam integer WPAIR = `FIR_WACC + 1;

`include "fir_polyphase_coeffs.vh"

wire signed [`FIR_WIN-1:0] lane0_in = in_vec[`FIR_WIN-1:0];
wire signed [`FIR_WIN-1:0] lane1_in = in_vec[2*`FIR_WIN-1:`FIR_WIN];

wire signed [`FIR_L2_E0_UNIQ*`FIR_WCOEF-1:0] coeff_l2_e0_bus;
wire signed [`FIR_L2_E1_UNIQ*`FIR_WCOEF-1:0] coeff_l2_e1_bus;

wire signed [`FIR_WACC-1:0] u00_acc;
wire signed [`FIR_WACC-1:0] u01_acc;
wire signed [`FIR_WACC-1:0] u10_acc;
wire signed [`FIR_WACC-1:0] u11_acc;
wire signed [`FIR_WACC-1:0] u11_acc_d1;
wire                        branch_valid;

wire signed [WPAIR-1:0] lane0_sum = {{1{u00_acc[`FIR_WACC-1]}}, u00_acc} + {{1{u11_acc_d1[`FIR_WACC-1]}}, u11_acc_d1};
wire signed [WPAIR-1:0] lane1_sum = {{1{u01_acc[`FIR_WACC-1]}}, u01_acc} + {{1{u10_acc[`FIR_WACC-1]}}, u10_acc};
wire signed [`FIR_WOUT-1:0] out_lane0;
wire signed [`FIR_WOUT-1:0] out_lane1;

genvar g;
generate
for (g = 0; g < `FIR_L2_E0_UNIQ; g = g + 1) begin : g_l2_e0_coeff
    assign coeff_l2_e0_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l2_e0_coeff_at(g);
end
for (g = 0; g < `FIR_L2_E1_UNIQ; g = g + 1) begin : g_l2_e1_coeff
    assign coeff_l2_e1_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l2_e1_coeff_at(g);
end
endgenerate

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L2_E0_TAPS),
    .UNIQ(`FIR_L2_E0_UNIQ)
) u_e0_x0 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(lane0_in),
    .coeff_bus(coeff_l2_e0_bus),
    .acc_out(u00_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L2_E0_TAPS),
    .UNIQ(`FIR_L2_E0_UNIQ)
) u_e0_x1 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(lane1_in),
    .coeff_bus(coeff_l2_e0_bus),
    .acc_out(u01_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L2_E1_TAPS),
    .UNIQ(`FIR_L2_E1_UNIQ)
) u_e1_x0 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(lane0_in),
    .coeff_bus(coeff_l2_e1_bus),
    .acc_out(u10_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L2_E1_TAPS),
    .UNIQ(`FIR_L2_E1_UNIQ)
) u_e1_x1 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(lane1_in),
    .coeff_bus(coeff_l2_e1_bus),
    .acc_out(u11_acc)
);

valid_pipe #(
    .LATENCY(1)
) u_branch_valid (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .out_valid(branch_valid)
);

fir_delay_signed #(
    .WIDTH(`FIR_WACC),
    .DEPTH(1)
) u_u11_delay (
    .clk(clk),
    .rst(rst),
    .en(branch_valid),
    .din(u11_acc),
    .dout(u11_acc_d1)
);

round_sat #(
    .IN_WIDTH(WPAIR),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_0 (
    .din(lane0_sum),
    .dout(out_lane0)
);

round_sat #(
    .IN_WIDTH(WPAIR),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_1 (
    .din(lane1_sum),
    .dout(out_lane1)
);

assign out_valid = branch_valid;
assign out_vec = {out_lane1, out_lane0};

endmodule
