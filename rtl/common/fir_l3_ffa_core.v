`timescale 1ns/1ps

`include "fir_params.vh"
`include "fir_polyphase_params.vh"

module fir_l3_ffa_core (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          in_valid,
    input  wire signed [`FIR_WIN-1:0]    lane0_in,
    input  wire signed [`FIR_WIN-1:0]    lane1_in,
    input  wire signed [`FIR_WIN-1:0]    lane2_in,
    output wire                          out_valid,
    output wire signed [`FIR_WACC+3:0]   y0_sum,
    output wire signed [`FIR_WACC+3:0]   y1_sum,
    output wire signed [`FIR_WACC+3:0]   y2_sum
);

localparam integer WIN2  = `FIR_WIN + 1;
localparam integer WIN3  = `FIR_WIN + 2;
localparam integer WACCX = `FIR_WACC + 2;
localparam integer WCORE = `FIR_WACC + 4;

`include "fir_polyphase_coeffs.vh"

wire signed [`FIR_WIN-1:0] lane2_d1;
wire signed [WIN2-1:0]     x01_in = {{1{lane0_in[`FIR_WIN-1]}}, lane0_in} + {{1{lane1_in[`FIR_WIN-1]}}, lane1_in};
wire signed [WIN2-1:0]     x12_in = {{1{lane1_in[`FIR_WIN-1]}}, lane1_in} + {{1{lane2_in[`FIR_WIN-1]}}, lane2_in};
wire signed [WIN3-1:0]     x012_in = {{2{lane0_in[`FIR_WIN-1]}}, lane0_in}
                                   + {{2{lane1_in[`FIR_WIN-1]}}, lane1_in}
                                   + {{2{lane2_in[`FIR_WIN-1]}}, lane2_in};

wire signed [`FIR_L3_E0_TAPS*`FIR_WCOEF-1:0]   coeff_l3_e0_bus;
wire signed [`FIR_L3_H01_TAPS*`FIR_WCOEF-1:0]  coeff_l3_h01_bus;
wire signed [`FIR_L3_H12_TAPS*`FIR_WCOEF-1:0]  coeff_l3_h12_bus;
wire signed [`FIR_L3_E1_UNIQ*`FIR_WCOEF-1:0]   coeff_l3_e1_bus;
wire signed [`FIR_L3_H012_UNIQ*`FIR_WCOEF-1:0] coeff_l3_h012_bus;

wire signed [WACCX-1:0] a_pair_acc;
wire signed [WACCX-1:0] h01_acc;
wire signed [WACCX-1:0] h12_acc;
wire signed [WACCX-1:0] h1_acc;
wire signed [WACCX-1:0] h012_acc;
wire                    branch_valid;

wire signed [WACCX-1:0] temp_a = a_pair_acc;
wire signed [WACCX-1:0] temp_b = h01_acc - h1_acc;
wire signed [WACCX-1:0] temp_c_raw = h12_acc - h1_acc;
wire signed [WACCX-1:0] temp_d = h012_acc;

wire signed [WACCX-1:0] temp_c_d1;
wire signed [WCORE-1:0] temp_a_ext   = {{(WCORE-WACCX){temp_a[WACCX-1]}}, temp_a};
wire signed [WCORE-1:0] temp_b_ext   = {{(WCORE-WACCX){temp_b[WACCX-1]}}, temp_b};
wire signed [WCORE-1:0] temp_c_d1_ext = {{(WCORE-WACCX){temp_c_d1[WACCX-1]}}, temp_c_d1};
wire signed [WCORE-1:0] temp_d_ext   = {{(WCORE-WACCX){temp_d[WACCX-1]}}, temp_d};
wire signed [WCORE-1:0] h01_ext      = {{(WCORE-WACCX){h01_acc[WACCX-1]}}, h01_acc};
wire signed [WCORE-1:0] h12_ext      = {{(WCORE-WACCX){h12_acc[WACCX-1]}}, h12_acc};
wire signed [WCORE-1:0] h1_twice_ext = {{(WCORE-WACCX-1){h1_acc[WACCX-1]}}, h1_acc, 1'b0};

genvar g;
generate
for (g = 0; g < `FIR_L3_E0_TAPS; g = g + 1) begin : g_l3_e0_coeff
    assign coeff_l3_e0_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_e0_coeff_at(g);
end
for (g = 0; g < `FIR_L3_H01_TAPS; g = g + 1) begin : g_l3_h01_coeff
    assign coeff_l3_h01_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_h01_coeff_at(g);
end
for (g = 0; g < `FIR_L3_H12_TAPS; g = g + 1) begin : g_l3_h12_coeff
    assign coeff_l3_h12_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_h12_coeff_at(g);
end
for (g = 0; g < `FIR_L3_E1_UNIQ; g = g + 1) begin : g_l3_e1_coeff
    assign coeff_l3_e1_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_e1_coeff_at(g);
end
for (g = 0; g < `FIR_L3_H012_UNIQ; g = g + 1) begin : g_l3_h012_coeff
    assign coeff_l3_h012_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_h012_coeff_at(g);
end
endgenerate

fir_delay_signed #(
    .WIDTH(`FIR_WIN),
    .DEPTH(1)
) u_lane2_delay (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .din(lane2_in),
    .dout(lane2_d1)
);

fir_branch_core_mirror_pair #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(WACCX),
    .TAPS(`FIR_L3_E0_TAPS),
    .NEGATE_B(1),
    .USE_DSP(1)
) u_pair_a (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample_a(lane0_in),
    .in_sample_b(lane2_d1),
    .coeff_bus(coeff_l3_e0_bus),
    .acc_out(a_pair_acc)
);

fir_branch_core_full #(
    .WIN(WIN2),
    .WCOEF(`FIR_WCOEF),
    .WACC(WACCX),
    .TAPS(`FIR_L3_H01_TAPS),
    .USE_DSP(0)
) u_h01_x01 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(x01_in),
    .coeff_bus(coeff_l3_h01_bus),
    .acc_out(h01_acc)
);

fir_branch_core_full #(
    .WIN(WIN2),
    .WCOEF(`FIR_WCOEF),
    .WACC(WACCX),
    .TAPS(`FIR_L3_H12_TAPS),
    .USE_DSP(0)
) u_h12_x12 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(x12_in),
    .coeff_bus(coeff_l3_h12_bus),
    .acc_out(h12_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(WACCX),
    .TAPS(`FIR_L3_E1_TAPS),
    .UNIQ(`FIR_L3_E1_UNIQ)
) u_h1_x1 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(lane1_in),
    .coeff_bus(coeff_l3_e1_bus),
    .acc_out(h1_acc)
);

fir_branch_core_symm #(
    .WIN(WIN3),
    .WCOEF(`FIR_WCOEF),
    .WACC(WACCX),
    .TAPS(`FIR_L3_H012_TAPS),
    .UNIQ(`FIR_L3_H012_UNIQ)
) u_h012_x012 (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .in_sample(x012_in),
    .coeff_bus(coeff_l3_h012_bus),
    .acc_out(h012_acc)
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
    .WIDTH(WACCX),
    .DEPTH(1)
) u_temp_c_delay (
    .clk(clk),
    .rst(rst),
    .en(branch_valid),
    .din(temp_c_raw),
    .dout(temp_c_d1)
);

assign y0_sum = temp_a_ext + temp_c_d1_ext;
assign y1_sum = temp_b_ext - temp_a_ext;
assign y2_sum = temp_d_ext - h01_ext - h12_ext + h1_twice_ext;

assign out_valid = branch_valid;

endmodule
